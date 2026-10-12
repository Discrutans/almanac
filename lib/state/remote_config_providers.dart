import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../platform/platform_config_repository.dart';
import '../platform/server_url.dart';
import 'app_providers.dart';

/// Есть ли у активного профиля свой Server URL (не общий dart-define).
bool hasConfiguredServerUrl({
  required AppConfig config,
  required PlatformConfigRepository platformConfigRepository,
  required String activeProfileId,
}) {
  final profileConfig = platformConfigRepository.getOrCreateConfig(
    profileId: activeProfileId,
  );
  return normalizeServerUrl(profileConfig.serverBaseUrl).isNotEmpty;
}

/// Разрешена ли синхронизация календаря на сервер.
bool isRemoteSyncConfigured({
  required AppConfig config,
  required PlatformConfigRepository platformConfigRepository,
  required String activeProfileId,
  bool ydbConfigured = false,
}) {
  if (ydbConfigured) return true;
  if (!hasConfiguredServerUrl(
    config: config,
    platformConfigRepository: platformConfigRepository,
    activeProfileId: activeProfileId,
  )) {
    return false;
  }
  return config.enableRemoteSync ||
      config.serverUrl.isNotEmpty ||
      normalizeServerUrl(
        platformConfigRepository
            .getOrCreateConfig(profileId: activeProfileId)
            .serverBaseUrl,
      ).isNotEmpty;
}

/// Разрешены ли сессии / REST API (достаточно URL в профиле).
bool isRemotePlatformConfigured({
  required AppConfig config,
  required PlatformConfigRepository platformConfigRepository,
  required String activeProfileId,
}) {
  return hasConfiguredServerUrl(
    config: config,
    platformConfigRepository: platformConfigRepository,
    activeProfileId: activeProfileId,
  );
}

final hasConfiguredServerProvider = Provider<bool>((ref) {
  ref.watch(platformSettingsRevisionProvider);

  final profileId = ref.watch(activeProfileIdProvider);
  return hasConfiguredServerUrl(
    config: ref.watch(appConfigProvider),
    platformConfigRepository: ref.watch(platformConfigRepositoryProvider),
    activeProfileId: profileId,
  );
});

final hasWorkspaceBackendProvider = Provider<bool>((ref) {
  ref.watch(platformSettingsRevisionProvider);
  if (ref.watch(localDataStoreProvider).ydbConnectionStore.isConfigured) {
    return true;
  }
  final profileId = ref.watch(activeProfileIdProvider);
  return hasConfiguredServerUrl(
    config: ref.watch(appConfigProvider),
    platformConfigRepository: ref.watch(platformConfigRepositoryProvider),
    activeProfileId: profileId,
  );
});

final isRemoteSyncConfiguredProvider = Provider<bool>((ref) {
  ref.watch(platformSettingsRevisionProvider);

  final profileId = ref.watch(activeProfileIdProvider);
  return isRemoteSyncConfigured(
    config: ref.watch(appConfigProvider),
    platformConfigRepository: ref.watch(platformConfigRepositoryProvider),
    activeProfileId: profileId,
    ydbConfigured: ref
        .watch(localDataStoreProvider)
        .ydbConnectionStore
        .isConfigured,
  );
});
