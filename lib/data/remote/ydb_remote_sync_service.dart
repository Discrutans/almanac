import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../platform/platform_config_repository.dart';
import '../../platform/platform_types.dart';
import '../../platform/ydb/ydb_connect_error.dart';
import '../../platform/ydb/ydb_connection_store.dart';
import '../../platform/ydb/ydb_snapshot_client.dart';
import '../../platform/ydb/ydb_workspace_connection.dart';
import '../local/local_data_codec.dart';
import '../local/local_data_store.dart';
import 'remote_sync_service.dart';
import 'sync_strategy.dart';

/// Snapshot-sync напрямую в Yandex YDB (без домена и FastAPI).
final class YdbRemoteSyncService implements RemoteSyncService {
  YdbRemoteSyncService({
    required LocalDataStore store,
    required PlatformConfigRepository platformConfigRepository,
    required YdbConnectionStore ydbStore,
    Locale locale = AppLocalizations.fallback,
  }) : _store = store,
       _platformConfigRepository = platformConfigRepository,
       _ydbStore = ydbStore,
       _l10n = AppLocalizations.forLocale(locale);

  final LocalDataStore _store;
  final PlatformConfigRepository _platformConfigRepository;
  final YdbConnectionStore _ydbStore;
  final AppLocalizations _l10n;

  static const _workspaceProfileId = 'default';

  @override
  bool get isEnabled => _ydbStore.isConfigured;

  YdbWorkspaceConnection? get _ydb => _ydbStore.active;

  String get _apiKey {
    final ydb = _ydb;
    if (ydb != null && ydb.workspaceApiKey.trim().isNotEmpty) {
      return ydb.workspaceApiKey.trim();
    }
    return _connection().apiKey;
  }

  PlatformConfig _connection({String? profileId}) {
    final id = profileId ?? _store.profileRepository.getActive().id;
    return _platformConfigRepository.getOrCreateConfig(profileId: id);
  }

  Future<YdbSnapshotClient> _open() async {
    final ydb = _ydb;
    if (ydb == null || !ydb.isConfigured) {
      throw StateError('YDB не настроена');
    }
    return openYdbSnapshotClient(ydb);
  }

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
      final full = _store.exportSnapshot();
      final sliceIds = allProfiles
          ? _idsSharingApiKey(full, _apiKey)
          : {onlyProfileId ?? activeId};
      final ids = sliceIds.isEmpty ? {activeId} : sliceIds;
      final merged = await _remoteMergedWithProfiles(full, ids);
      final client = await _open();
      await client.putSnapshot(
        apiKey: _apiKey,
        profileId: _workspaceProfileId,
        snapshot: merged.toJson(),
        updatedAt: DateTime.now().toUtc(),
      );
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
        message: _l10n.syncPushFailed(formatYdbConnectError(error)),
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
      final client = await _open();
      final record = await client.getSnapshot(
        apiKey: _apiKey,
        profileId: _workspaceProfileId,
      );
      final snapshotJson = record.snapshot;
      if (snapshotJson == null) {
        return RemoteSyncResult(
          success: true,
          message: _l10n.syncNoRemoteDataYet,
        );
      }
      final remoteUpdated = record.updatedAt;
      final localUpdated = _store.exportSnapshot().updatedAt;
      final direction = resolveSyncDirection(
        localUpdated: localUpdated ?? DateTime.fromMillisecondsSinceEpoch(0),
        remoteUpdated: remoteUpdated,
      );
      final snapshot = LocalDataSnapshot.fromJson(snapshotJson);

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
          ..._idsSharingApiKey(_store.exportSnapshot(), _apiKey),
          ..._idsSharingApiKey(snapshot, _apiKey),
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
      return RemoteSyncResult(
        success: false,
        message: formatYdbConnectError(error),
      );
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

  Set<String> _idsSharingApiKey(LocalDataSnapshot snapshot, String apiKey) {
    final key = apiKey.trim();
    if (key.isEmpty) return {};
    return {
      for (final entry in snapshot.platformConfigsByProfile.entries)
        if (entry.value.apiKey.trim() == key) entry.key,
    };
  }

  Future<LocalDataSnapshot> _remoteMergedWithProfiles(
    LocalDataSnapshot local,
    Set<String> profileIds,
  ) async {
    final slice = local.sliceForProfiles(profileIds);
    try {
      final client = await _open();
      final record = await client.getSnapshot(
        apiKey: _apiKey,
        profileId: _workspaceProfileId,
      );
      final snapshotJson = record.snapshot;
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
