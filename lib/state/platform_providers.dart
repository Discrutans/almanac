import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/almanac_platform_api.dart';
import '../platform/mini_server/mini_server_controller.dart';
import '../platform/remote_almanac_platform_api.dart';
import '../platform/server_url.dart';
import '../platform/session_types.dart';
import 'core_providers.dart';
import 'profile_providers.dart';
import 'repository_providers.dart';

/// Базовый URL для публичных deep link (/join/:token).
/// Если PUBLIC_ORIGIN не задан — используется Server URL профиля или dart-define.
final publicOriginProvider = Provider<String>((ref) {
  const fromEnv = String.fromEnvironment('PUBLIC_ORIGIN');
  if (fromEnv.isNotEmpty) return normalizeServerUrl(fromEnv);

  final profileId = ref.watch(activeProfileIdProvider);

  final platformConfig = ref
      .watch(platformConfigRepositoryProvider)
      .getOrCreateConfig(profileId: profileId);
  if (platformConfig.publicOrigin.isNotEmpty) {
    return normalizeServerUrl(platformConfig.publicOrigin);
  }
  if (platformConfig.serverBaseUrl.isNotEmpty) {
    return normalizeServerUrl(platformConfig.serverBaseUrl);
  }

  final appServer = ref.watch(appConfigProvider).serverUrl;
  if (appServer.isNotEmpty) return normalizeServerUrl(appServer);

  return 'http://localhost:8080';
});

final miniServerControllerProvider =
    ChangeNotifierProvider<MiniServerController>((ref) {
      final controller = MiniServerController(
        store: ref.watch(localDataStoreProvider),
        platformConfigRepository: ref.watch(platformConfigRepositoryProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final almanacPlatformApiProvider = Provider<AlmanacPlatformApi>((ref) {
  ref.watch(platformSettingsRevisionProvider);

  final profileId = ref.watch(activeProfileIdProvider);

  final configRepo = ref.watch(platformConfigRepositoryProvider);

  final platformConfig = configRepo.getOrCreateConfig(profileId: profileId);

  final appConfig = ref.watch(appConfigProvider);

  final serverUrl = normalizeServerUrl(
    platformConfig.serverBaseUrl.isNotEmpty
        ? platformConfig.serverBaseUrl
        : appConfig.serverUrl,
  );

  if (serverUrl.isNotEmpty) {
    return RemoteAlmanacPlatformApi(
      platformConfigRepository: configRepo,
      baseUrl: serverUrl,
      publicOrigin: ref.watch(publicOriginProvider),
    );
  }

  return LocalAlmanacPlatformApi(
    bookingRepository: ref.watch(bookingRepositoryProvider),
    groupPlanRepository: ref.watch(groupPlanRepositoryProvider),
    platformConfigRepository: configRepo,
    publicOrigin: ref.watch(publicOriginProvider),
  );
});

final remotePlatformApiProvider = Provider<RemoteAlmanacPlatformApi?>((ref) {
  final api = ref.watch(almanacPlatformApiProvider);
  return api is RemoteAlmanacPlatformApi ? api : null;
});

final sessionLinksProvider =
    FutureProvider.family<List<CreateSessionResult>, String>((
      ref,
      profileId,
    ) async {
      final remote = ref.watch(remotePlatformApiProvider);
      if (remote == null) return const [];
      final sessions = await remote.listSessionsRemote(profileId: profileId);
      final origin = ref.watch(publicOriginProvider);
      return sessions
          .map((session) {
            final slots = session.state.slots;
            final firstSlot = slots.firstOrNull;
            return CreateSessionResult(
              id: session.id,
              token: session.token,
              deepLink:
                  '${origin.replaceAll(RegExp(r'/$'), '')}/join/${session.token}',
              mode: session.mode,
              title: session.title,
              isOpen: session.isOpen,
              accentColor: firstSlot?.color,
              durationMinutes: firstSlot?.end
                  .difference(firstSlot.start)
                  .inMinutes,
            );
          })
          .toList();
    });
