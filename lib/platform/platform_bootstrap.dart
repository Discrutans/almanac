import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../data/local/local_data_store.dart';
import '../data/remote/remote_auto_sync.dart';
import '../data/remote/sync_ui_helpers.dart';
import 'platform_types.dart';
import '../state/app_providers.dart';
import '../state/remote_config_providers.dart';
import '../platform/push_notification_service.dart';
import '../platform/high_refresh_rate.dart';
import '../state/session_pending_providers.dart';

final remoteAutoSyncSchedulerProvider = Provider<RemoteAutoSyncScheduler>((
  ref,
) {
  final scheduler = RemoteAutoSyncScheduler(
    () => ref.read(remoteSyncServiceProvider),
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

/// Подключает self-hosted backend при старте: pending-заявки, регистрация устройства.
class PlatformBootstrap extends ConsumerStatefulWidget {
  const PlatformBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PlatformBootstrap> createState() => _PlatformBootstrapState();
}

class _PlatformBootstrapState extends ConsumerState<PlatformBootstrap>
    with WidgetsBindingObserver {
  static const _pendingPollInterval = Duration(seconds: 10);

  late final LocalDataStore _store;
  late final void Function() _persistHandler;
  Timer? _pendingPollTimer;

  @override
  void initState() {
    super.initState();
    _store = ref.read(localDataStoreProvider);
    _persistHandler = _scheduleAutoSync;
    ref.read(remoteAutoSyncSchedulerProvider).onRestored = () {
      refreshAfterRemoteRestore(ref);
    };
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_store.onPersisted == _persistHandler) {
      _store.onPersisted = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(HighRefreshRate.configure());
      _refreshRemote();
    }
  }

  Future<void> _bootstrap() async {
    await PushNotificationService.instance.initialize();
    PushNotificationService.instance.listen((_) => _refreshRemote());
    _wireAutoSync();
    _startPendingPoll();
    await _refreshRemote();
    await _registerDevice();
  }

  void _startPendingPoll() {
    _pendingPollTimer?.cancel();
    _pendingPollTimer = Timer.periodic(_pendingPollInterval, (_) {
      _refreshRemote();
    });
  }

  void _wireAutoSync() {
    _store.onPersisted = _persistHandler;
  }

  void _scheduleAutoSync() {
    if (!ref.read(isRemoteSyncConfiguredProvider)) return;
    if (!ref.read(appConfigProvider).enableAutoRemoteSync) return;
    final profileId = ref.read(activeProfileIdProvider);
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profileId);
    if (!config.autoPush) return;
    ref
        .read(remoteAutoSyncSchedulerProvider)
        .schedulePush(onlyProfileId: profileId);
  }

  Future<void> _refreshRemote() async {
    if (ref.read(remotePlatformApiProvider) != null) {
      refreshRemoteSessionPending(ref);
    }
    if (!ref.read(isRemoteSyncConfiguredProvider)) return;
    if (!ref.read(appConfigProvider).enableAutoRemoteSync) return;
    final profileId = ref.read(activeProfileIdProvider);
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profileId);
    if (config.autoPull) {
      await ref
          .read(remoteAutoSyncSchedulerProvider)
          .syncNow(pushIfLocalNewer: false, onlyProfileId: profileId);
    }
    await _refreshEventLocks();
  }

  Future<void> _refreshEventLocks() async {
    try {
      await ref.read(eventLockServiceProvider).refreshActive();
      ref.read(eventLocksRevisionProvider.notifier).state++;
    } catch (_) {
      // Locks are best-effort; edit still checks acquire().
    }
  }

  String _deviceToken(AppConfig config, PlatformConfig platformConfig) {
    if (config.pushDeviceToken.isNotEmpty) return config.pushDeviceToken;
    if (platformConfig.pushToken.isNotEmpty) return platformConfig.pushToken;
    if (platformConfig.deviceId.isNotEmpty) return platformConfig.deviceId;
    return platformConfig.apiKey;
  }

  Future<void> _registerDevice() async {
    final remote = ref.read(remotePlatformApiProvider);
    if (remote == null) return;

    final profileId = ref.read(activeProfileIdProvider);
    final appConfig = ref.read(appConfigProvider);
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profileId);
    if (!config.notificationsEnabled) return;

    try {
      await remote.verifyWorkspace(profileId: profileId);
      final pushToken = await PushNotificationService.instance.currentToken(
        config: appConfig,
        platformConfig: config,
      );
      await remote.registerDeviceToken(
        profileId: profileId,
        token: pushToken ?? _deviceToken(appConfig, config),
        platform: defaultTargetPlatform.name,
      );
    } catch (_) {
      // Server may be offline at startup.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(platformSettingsRevisionProvider, (previous, next) {
      if (previous != next) {
        unawaited(_registerDevice());
        unawaited(_refreshRemote());
      }
    });
    ref.listen(remotePlatformApiProvider, (previous, next) {
      if (previous?.baseUrl != next?.baseUrl) {
        unawaited(_registerDevice());
        unawaited(_refreshRemote());
      }
    });
    return widget.child;
  }
}
