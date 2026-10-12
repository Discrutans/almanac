import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/network/almanac_http.dart';
import '../../core/localization/app_localizations.dart';
import '../../platform/platform_config_repository.dart';
import '../../platform/platform_types.dart';
import '../../platform/server_url.dart';
import '../local/local_data_codec.dart';
import '../local/local_data_store.dart';
import '../../state/remote_config_providers.dart';
import 'remote_sync_service.dart';
import 'sync_strategy.dart';

/// Calendar snapshot sync via self-hosted Almanac Platform API.
final class AlmanacRemoteSyncService implements RemoteSyncService {
  AlmanacRemoteSyncService({
    required AppConfig config,
    required LocalDataStore store,
    required PlatformConfigRepository platformConfigRepository,
    Locale locale = AppLocalizations.fallback,
    http.Client? httpClient,
  }) : _config = config,
       _store = store,
       _platformConfigRepository = platformConfigRepository,
       _l10n = AppLocalizations.forLocale(locale),
       _http = almanacHttpClient(inner: httpClient);

  final AppConfig _config;
  final LocalDataStore _store;
  final PlatformConfigRepository _platformConfigRepository;
  final AppLocalizations _l10n;
  final http.Client _http;

  String get _baseUrl {
    final fromProfile = normalizeServerUrl(_connection().serverBaseUrl);
    if (fromProfile.isNotEmpty) return fromProfile;
    return normalizeServerUrl(_config.serverUrl);
  }

  @override
  bool get isEnabled => isRemoteSyncConfigured(
    config: _config,
    platformConfigRepository: _platformConfigRepository,
    activeProfileId: _store.profileRepository.getActive().id,
  );

  static const _workspaceProfileId = 'default';

  PlatformConfig _connection({String? profileId}) {
    final id = profileId ?? _store.profileRepository.getActive().id;
    return _platformConfigRepository.getOrCreateConfig(profileId: id);
  }

  Map<String, String> _headers(String apiKey) {
    return {
      'Content-Type': 'application/json',
      'X-Api-Key': apiKey,
      'X-Profile-Id': _workspaceProfileId,
    };
  }

  String get _apiKey => _connection().apiKey;

  @override
  Future<RemoteSyncResult> pushLocalChanges({
    String? onlyProfileId,
    bool allProfiles = false,
  }) async {
    if (!isEnabled) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncDisabledEnvHint,
      );
    }

    try {
      final activeId = _store.profileRepository.getActive().id;
      final connection = _connection(profileId: activeId);
      final full = _store.exportSnapshot();
      final sliceIds = allProfiles
          ? full.profileIdsSharingConnection(connection)
          : {onlyProfileId ?? activeId};
      final ids = sliceIds.isEmpty ? {activeId} : sliceIds;
      final snapshot = await _remoteMergedWithProfiles(full, ids);
      final response = await _http.post(
        Uri.parse('$_baseUrl/v1/calendar/snapshot'),
        headers: _headers(connection.apiKey),
        body: jsonEncode({
          'profile_id': _workspaceProfileId,
          'snapshot': snapshot.toJson(),
          'merge_profile_ids': ids.toList(),
        }),
      );
      if (response.statusCode >= 400) {
        return RemoteSyncResult(
          success: false,
          message: _l10n.syncPushFailed(response.body),
        );
      }
      if (ids.length == 1) {
        final profileId = ids.first;
        final name =
            _store.profileRepository.getById(profileId)?.name ?? profileId;
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncPushProfileSuccess(name),
        );
      }
      return RemoteSyncResult(success: true, message: _l10n.syncPushSuccess);
    } catch (error) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncPushFailed(error),
      );
    }
  }

  @override
  Future<RemoteSyncResult> pullRemoteChanges({
    bool forceReplaceLocal = false,
    String? onlyProfileId,
  }) async {
    if (!isEnabled) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncDisabledEnvHint,
      );
    }

    try {
      final response = await _http.get(
        Uri.parse('$_baseUrl/v1/calendar/snapshot'),
        headers: _headers(_apiKey),
      );
      if (response.statusCode >= 400) {
        return RemoteSyncResult(success: false, message: response.body);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final snapshotJson = json['snapshot'] as Map<String, dynamic>?;
      if (snapshotJson == null) {
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncNoRemoteDataYet,
        );
      }

      final remoteUpdatedRaw = json['updated_at'] as String?;
      final remoteUpdated = remoteUpdatedRaw == null
          ? null
          : DateTime.parse(remoteUpdatedRaw);
      final localUpdated = _store.exportSnapshot().updatedAt;

      final direction = resolveSyncDirection(
        localUpdated: localUpdated ?? DateTime.fromMillisecondsSinceEpoch(0),
        remoteUpdated: remoteUpdated,
      );

      final snapshot = LocalDataSnapshot.fromJson(snapshotJson);
      final connection = _connection();

      if (onlyProfileId != null) {
        if (!snapshot.containsProfile(onlyProfileId)) {
          return RemoteSyncResult(
            success: true,
            message: _l10n.syncProfileMissingOnServer,
            conflictWithLocal: direction == SyncDirection.push,
          );
        }
        if (forceReplaceLocal) {
          await _store.restoreProfileSlice(
            remote: snapshot,
            profileId: onlyProfileId,
          );
        } else {
          final changed = await _store.unionProfileSlice(
            remote: snapshot,
            profileId: onlyProfileId,
            remoteWinsConflicts: direction == SyncDirection.pull,
          );
          if (!changed) {
            if (direction == SyncDirection.push) {
              return RemoteSyncResult(
                success: true,
                message: _l10n.syncConflictTitle,
                conflictWithLocal: true,
              );
            }
            return RemoteSyncResult(
              success: true,
              message: _l10n.syncAlreadyUpToDate,
            );
          }
        }
        final name =
            _store.profileRepository.getById(onlyProfileId)?.name ??
            onlyProfileId;
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncPullProfileSuccess(name),
          restoredFromRemote: true,
        );
      }

      if (direction == SyncDirection.pull || forceReplaceLocal) {
        final ids = {
          ..._store.exportSnapshot().profileIdsSharingConnection(connection),
          ...snapshot.profileIdsSharingConnection(connection),
        };
        await _store.mergeRemoteSnapshot(snapshot, onlyProfileIds: ids);
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncPulledNewerRemoteData,
          restoredFromRemote: true,
        );
      }

      if (direction == SyncDirection.upToDate) {
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncAlreadyUpToDate,
        );
      }

      return RemoteSyncResult(
        success: true,
        message: _l10n.syncConflictTitle,
        conflictWithLocal: true,
      );
    } catch (error) {
      return RemoteSyncResult(success: false, message: error.toString());
    }
  }

  @override
  Future<RemoteSyncResult> syncAll() async {
    if (!isEnabled) {
      return RemoteSyncResult(
        success: false,
        message: _l10n.syncDisabledEnvHint,
      );
    }

    final activeId = _store.profileRepository.getActive().id;
    final pull = await pullRemoteChanges(onlyProfileId: activeId);
    if (pull.conflictWithLocal || pull.restoredFromRemote) return pull;

    return pushLocalChanges(onlyProfileId: activeId);
  }

  Future<LocalDataSnapshot> _remoteMergedWithProfiles(
    LocalDataSnapshot local,
    Set<String> profileIds,
  ) async {
    final slice = local.sliceForProfiles(profileIds);
    try {
      final response = await _http.get(
        Uri.parse('$_baseUrl/v1/calendar/snapshot'),
        headers: _headers(_apiKey),
      );
      if (response.statusCode >= 400) return slice;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final snapshotJson = json['snapshot'] as Map<String, dynamic>?;
      if (snapshotJson == null) return slice;
      var remote = LocalDataSnapshot.fromJson(snapshotJson);
      for (final profileId in profileIds) {
        remote = remote.replacingProfile(local, profileId);
      }
      return remote;
    } catch (_) {
      return slice;
    }
  }
}
