import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/localization/app_localizations.dart';
import '../local/local_data_store.dart';
import 'almanac_remote_sync_service.dart';
import 'ydb_remote_sync_service.dart';
import '../../state/remote_config_providers.dart';

/// Статус попытки удалённой синхронизации.
class RemoteSyncResult {
  const RemoteSyncResult({
    required this.success,
    required this.message,
    this.restoredFromRemote = false,
    this.conflictWithLocal = false,
    this.keptLocalAfterConflict = false,
  });

  final bool success;
  final String message;
  final bool restoredFromRemote;
  final bool conflictWithLocal;
  final bool keptLocalAfterConflict;
}

/// Абстракция синхронизации с self-hosted Almanac API (или локальный no-op).
abstract interface class RemoteSyncService {
  bool get isEnabled;

  Future<RemoteSyncResult> pushLocalChanges({
    String? onlyProfileId,
    bool allProfiles = false,
  });

  Future<RemoteSyncResult> pullRemoteChanges({
    bool forceReplaceLocal = false,
    String? onlyProfileId,
  });

  Future<RemoteSyncResult> syncAll();
}

/// Фабрика сервиса синхронизации: Almanac API или локальная заглушка.
RemoteSyncService createRemoteSyncService({
  required AppConfig config,
  required LocalDataStore store,
  Locale locale = AppLocalizations.fallback,
}) {
  final profileId = store.profileRepository.getActive().id;
  if (store.ydbConnectionStore.isConfigured) {
    return YdbRemoteSyncService(
      store: store,
      platformConfigRepository: store.platformConfigRepository,
      ydbStore: store.ydbConnectionStore,
      locale: locale,
    );
  }
  if (isRemoteSyncConfigured(
    config: config,
    platformConfigRepository: store.platformConfigRepository,
    activeProfileId: profileId,
    ydbConfigured: false,
  )) {
    return AlmanacRemoteSyncService(
      config: config,
      store: store,
      platformConfigRepository: store.platformConfigRepository,
      locale: locale,
    );
  }
  return StubRemoteSyncService(locale: locale);
}

/// Локальная заглушка, когда сервер не настроен.
final class StubRemoteSyncService implements RemoteSyncService {
  StubRemoteSyncService({Locale locale = AppLocalizations.fallback})
    : _l10n = AppLocalizations.forLocale(locale);

  final AppLocalizations _l10n;

  @override
  bool get isEnabled => false;

  @override
  Future<RemoteSyncResult> pushLocalChanges({
    String? onlyProfileId,
    bool allProfiles = false,
  }) => _notReady(_l10n.pushChanges);

  @override
  Future<RemoteSyncResult> pullRemoteChanges({
    bool forceReplaceLocal = false,
    String? onlyProfileId,
  }) => _notReady(_l10n.pullChanges);

  @override
  Future<RemoteSyncResult> syncAll() async {
    if (!isEnabled) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncDisabledEnvHint,
      );
    }

    return RemoteSyncResult(
      success: false,
      message: _l10n.syncServerUrlRequired,
    );
  }

  Future<RemoteSyncResult> _notReady(String action) async {
    if (!isEnabled) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncActionUnavailable(action),
      );
    }

    return syncAll();
  }
}
