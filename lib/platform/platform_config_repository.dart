import 'package:uuid/uuid.dart';
import '../data/local/persisted_repository.dart';
import '../data/profiles/profile_kind.dart';
import 'platform_types.dart';
import 'server_url.dart';

const _uuid = Uuid();

/// Fixes configs loaded before newer fields existed (hot reload / old JSON).
PlatformConfig repairPlatformConfig(PlatformConfig config) {
  try {
    final _ = [
      config.publicOrigin,
      config.autoPush,
      config.autoPull,
      config.notificationsEnabled,
      config.role,
    ];
    return config;
  } catch (_) {
    return config.copyWith(
      publicOrigin: '',
      autoPush: true,
      autoPull: true,
      notificationsEnabled: true,
      role: ProfileRole.owner,
    );
  }
}

abstract interface class PlatformConfigRepository {
  PlatformConfig getOrCreateConfig({required String profileId});

  PlatformConfig updateServerUrl({
    required String profileId,
    required String serverBaseUrl,
  });

  PlatformConfig updateConnectionSettings({
    required String profileId,
    required String serverBaseUrl,
    required String apiKey,
    required String workspaceProfileId,
    String publicOrigin = '',
  });

  PlatformConfig updatePushToken({
    required String profileId,
    required String pushToken,
  });

  PlatformConfig updateSyncPreferences({
    required String profileId,
    bool? autoPush,
    bool? autoPull,
    bool? notificationsEnabled,
  });

  PlatformConfig updateRole({
    required String profileId,
    required ProfileRole role,
  });

  void deleteProfileData(String profileId);

  Set<String> idsSharingConnectionWith(String profileId);
}

class InMemoryPlatformConfigRepository
    with PersistedRepository
    implements PlatformConfigRepository {
  InMemoryPlatformConfigRepository();

  final _configsByProfile = <String, PlatformConfig>{};

  Map<String, PlatformConfig> exportConfigsByProfile() =>
      Map.unmodifiable(_configsByProfile);

  void restore({required Map<String, PlatformConfig> configsByProfile}) {
    _configsByProfile
      ..clear()
      ..addAll(
        configsByProfile.map(
          (profileId, config) =>
              MapEntry(profileId, repairPlatformConfig(config)),
        ),
      );
  }

  @override
  PlatformConfig getOrCreateConfig({required String profileId}) {
    final existing = _configsByProfile[profileId];
    if (existing != null) {
      var config = repairPlatformConfig(existing);
      var changed = !identical(config, existing);
      final fixedUrl = normalizeServerUrl(config.serverBaseUrl);
      if (fixedUrl != config.serverBaseUrl) {
        config = config.copyWith(serverBaseUrl: fixedUrl);
        changed = true;
      }
      if (config.deviceId.isEmpty) {
        config = config.copyWith(deviceId: _uuid.v4());
        changed = true;
      }
      if (changed) {
        _configsByProfile[profileId] = config;
        notifyChanged();
      }
      return config;
    }

    final config = PlatformConfig(
      profileId: profileId,
      apiKey: _uuid.v4(),
      deviceId: _uuid.v4(),
    );
    _configsByProfile[profileId] = config;
    notifyChanged();
    return config;
  }

  @override
  PlatformConfig updateServerUrl({
    required String profileId,
    required String serverBaseUrl,
  }) {
    final config = getOrCreateConfig(profileId: profileId);
    final updated = config.copyWith(
      serverBaseUrl: normalizeServerUrl(serverBaseUrl),
    );
    _configsByProfile[profileId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  PlatformConfig updateConnectionSettings({
    required String profileId,
    required String serverBaseUrl,
    required String apiKey,
    required String workspaceProfileId,
    String publicOrigin = '',
  }) {
    // HTTP workspace id is not stored as the context-profile key.
    final config = getOrCreateConfig(profileId: profileId);
    final trimmedKey = apiKey.trim();
    final normalizedOrigin = publicOrigin.trim().isEmpty
        ? ''
        : normalizeServerUrl(publicOrigin);
    final updated = config.copyWith(
      profileId: workspaceProfileId.trim().isEmpty
          ? profileId
          : workspaceProfileId.trim(),
      serverBaseUrl: normalizeServerUrl(serverBaseUrl),
      apiKey: trimmedKey.isEmpty ? config.apiKey : trimmedKey,
      publicOrigin: normalizedOrigin,
    );
    _configsByProfile[profileId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  PlatformConfig updatePushToken({
    required String profileId,
    required String pushToken,
  }) {
    final config = getOrCreateConfig(profileId: profileId);
    final updated = config.copyWith(pushToken: pushToken.trim());
    _configsByProfile[profileId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  PlatformConfig updateSyncPreferences({
    required String profileId,
    bool? autoPush,
    bool? autoPull,
    bool? notificationsEnabled,
  }) {
    final config = getOrCreateConfig(profileId: profileId);
    final updated = config.copyWith(
      autoPush: autoPush,
      autoPull: autoPull,
      notificationsEnabled: notificationsEnabled,
    );
    _configsByProfile[profileId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  PlatformConfig updateRole({
    required String profileId,
    required ProfileRole role,
  }) {
    final config = getOrCreateConfig(profileId: profileId);
    final updated = config.copyWith(role: role);
    _configsByProfile[profileId] = updated;
    notifyChanged();
    return updated;
  }

  @override
  void deleteProfileData(String profileId) {
    _configsByProfile.remove(profileId);
    notifyChanged();
  }

  @override
  Set<String> idsSharingConnectionWith(String profileId) {
    final connection = getOrCreateConfig(profileId: profileId);
    return {
      for (final entry in _configsByProfile.entries)
        if (sameRemoteWorkspace(
          serverBaseUrl: connection.serverBaseUrl,
          apiKey: connection.apiKey,
          otherServerBaseUrl: entry.value.serverBaseUrl,
          otherApiKey: entry.value.apiKey,
        ))
          entry.key,
    };
  }

  void keepLocalConnectionIfRemoteEmpty(Map<String, PlatformConfig> previous) {
    for (final entry in previous.entries) {
      final local = repairPlatformConfig(entry.value);
      if (local.serverBaseUrl.trim().isEmpty) continue;
      final remote = _configsByProfile[entry.key];
      if (remote != null &&
          repairPlatformConfig(remote).serverBaseUrl.trim().isNotEmpty) {
        continue;
      }
      final current = remote == null
          ? PlatformConfig(
              profileId: entry.key,
              apiKey: local.apiKey,
              deviceId: local.deviceId,
            )
          : repairPlatformConfig(remote);
      _configsByProfile[entry.key] = current.copyWith(
        profileId: local.profileId.isEmpty ? entry.key : local.profileId,
        serverBaseUrl: local.serverBaseUrl,
        apiKey: local.apiKey,
        publicOrigin: local.publicOrigin,
        autoPush: local.autoPush,
        autoPull: local.autoPull,
        notificationsEnabled: local.notificationsEnabled,
        role: local.role,
      );
    }
  }
}
