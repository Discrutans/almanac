import 'ydb_workspace_connection.dart';
import '../../data/remote/event_lock.dart';

class CalendarSnapshotRecord {
  const CalendarSnapshotRecord({this.snapshot, this.updatedAt});

  final Map<String, dynamic>? snapshot;
  final DateTime? updatedAt;
}

class YdbSnapshotClient {
  Future<void> ping() async {}

  Future<void> close() async {}

  Future<CalendarSnapshotRecord> getSnapshot({
    required String apiKey,
    String profileId = 'default',
  }) async {
    return const CalendarSnapshotRecord();
  }

  Future<void> putSnapshot({
    required String apiKey,
    required Map<String, dynamic> snapshot,
    String profileId = 'default',
    DateTime? updatedAt,
  }) async {}

  Future<bool> acquireLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    int ttlSeconds = 90,
  }) async {
    return true;
  }

  Future<bool> heartbeatLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    int ttlSeconds = 90,
  }) async {
    return true;
  }

  Future<void> releaseLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
  }) async {}

  Future<List<RemoteEventLock>> listLocks({required String apiKey}) async {
    return const [];
  }
}

Future<YdbSnapshotClient> openYdbSnapshotClient(
  YdbWorkspaceConnection connection,
) {
  throw UnsupportedError('YDB requires dart:io');
}

Future<void> closeSharedYdbSnapshotClient() async {}
