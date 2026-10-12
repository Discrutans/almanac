import 'dart:convert';

import 'package:ydb_flutter_sdk/ydb_flutter_sdk.dart';

import '../../data/remote/event_lock.dart';
import 'ydb_credentials_factory.dart';
import 'ydb_values.dart';
import 'ydb_workspace_connection.dart';

YdbSnapshotClient? _sharedClient;
String? _sharedFingerprint;

class CalendarSnapshotRecord {
  const CalendarSnapshotRecord({this.snapshot, this.updatedAt});

  final Map<String, dynamic>? snapshot;
  final DateTime? updatedAt;
}

class YdbSnapshotClient {
  YdbSnapshotClient._(this._driver, [this._iamTransport]);

  final YdbDriver _driver;
  final IYdbTransport? _iamTransport;

  static const _table = 'almanac_snapshots';
  static const _locksTable = 'almanac_event_locks';

  Future<void> ping() async {
    await _q('SELECT 1 AS ok;');
  }

  Future<void> close() async {
    await _driver.close();
    await _iamTransport?.close();
  }

  Future<bool> acquireLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    int ttlSeconds = 90,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await _readLock(apiKey: apiKey, eventId: eventId);
    if (!canTakeEventLock(
      deviceId: deviceId,
      now: now,
      holderDeviceId: existing?.deviceId,
      expiresAt: existing?.expiresAt,
    )) {
      return false;
    }
    final expires = now.add(Duration(seconds: ttlSeconds.clamp(15, 600)));
    await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $event_id AS Utf8;
      DECLARE $device_id AS Utf8;
      DECLARE $expires_at AS Timestamp;
      UPSERT INTO almanac_event_locks (api_key, event_id, device_id, expires_at)
      VALUES ($api_key, $event_id, $device_id, $expires_at);
      ''',
      {
        'api_key': YdbUtf8(apiKey),
        'event_id': YdbUtf8(eventId),
        'device_id': YdbUtf8(deviceId),
        'expires_at': YdbTimestamp(expires),
      },
    );
    return true;
  }

  Future<bool> heartbeatLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    int ttlSeconds = 90,
  }) async {
    final now = DateTime.now().toUtc();
    final existing = await _readLock(apiKey: apiKey, eventId: eventId);
    if (existing == null ||
        existing.deviceId != deviceId ||
        existing.isExpired(now)) {
      return false;
    }
    return acquireLock(
      apiKey: apiKey,
      eventId: eventId,
      deviceId: deviceId,
      ttlSeconds: ttlSeconds,
    );
  }

  Future<void> releaseLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
  }) async {
    await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $event_id AS Utf8;
      DECLARE $device_id AS Utf8;
      DELETE FROM almanac_event_locks
      WHERE api_key = $api_key
        AND event_id = $event_id
        AND device_id = $device_id;
      ''',
      {
        'api_key': YdbUtf8(apiKey),
        'event_id': YdbUtf8(eventId),
        'device_id': YdbUtf8(deviceId),
      },
    );
  }

  Future<List<RemoteEventLock>> listLocks({required String apiKey}) async {
    final now = DateTime.now().toUtc();
    final result = await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $now AS Timestamp;
      SELECT event_id, device_id, expires_at
      FROM almanac_event_locks
      WHERE api_key = $api_key AND expires_at > $now;
      ''',
      {'api_key': YdbUtf8(apiKey), 'now': YdbTimestamp(now)},
    );
    return [
      for (final row in result.rows)
        RemoteEventLock(
          eventId: ydbRowString(row, 'event_id'),
          deviceId: ydbRowString(row, 'device_id'),
          expiresAt: ydbRowTime(row, 'expires_at'),
        ),
    ];
  }

  Future<RemoteEventLock?> _readLock({
    required String apiKey,
    required String eventId,
  }) async {
    final result = await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $event_id AS Utf8;
      SELECT event_id, device_id, expires_at
      FROM almanac_event_locks
      WHERE api_key = $api_key AND event_id = $event_id;
      ''',
      {'api_key': YdbUtf8(apiKey), 'event_id': YdbUtf8(eventId)},
    );
    if (result.rows.isEmpty) return null;
    final row = result.rows.first;
    return RemoteEventLock(
      eventId: ydbRowString(row, 'event_id'),
      deviceId: ydbRowString(row, 'device_id'),
      expiresAt: ydbRowTime(row, 'expires_at'),
    );
  }

  Future<CalendarSnapshotRecord> getSnapshot({
    required String apiKey,
    String profileId = 'default',
  }) async {
    final result = await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $profile_id AS Utf8;
      SELECT snapshot_json, updated_at
      FROM almanac_snapshots
      WHERE api_key = $api_key AND profile_id = $profile_id;
      ''',
      {'api_key': YdbUtf8(apiKey), 'profile_id': YdbUtf8(profileId)},
    );
    if (result.rows.isEmpty) return const CalendarSnapshotRecord();
    final row = result.rows.first;
    final raw = ydbRowString(row, 'snapshot_json');
    Map<String, dynamic>? snapshot;
    if (raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        snapshot = decoded;
      } else if (decoded is Map) {
        snapshot = Map<String, dynamic>.from(decoded);
      }
    }
    return CalendarSnapshotRecord(
      snapshot: snapshot,
      updatedAt: ydbRowTime(row, 'updated_at'),
    );
  }

  Future<void> putSnapshot({
    required String apiKey,
    required Map<String, dynamic> snapshot,
    String profileId = 'default',
    DateTime? updatedAt,
  }) async {
    final stamp = (updatedAt ?? DateTime.now()).toUtc();
    await _q(
      r'''
      DECLARE $api_key AS Utf8;
      DECLARE $profile_id AS Utf8;
      DECLARE $snapshot_json AS Utf8;
      DECLARE $updated_at AS Timestamp;
      UPSERT INTO almanac_snapshots (api_key, profile_id, snapshot_json, updated_at)
      VALUES ($api_key, $profile_id, $snapshot_json, $updated_at);
      ''',
      {
        'api_key': YdbUtf8(apiKey),
        'profile_id': YdbUtf8(profileId),
        'snapshot_json': YdbUtf8(jsonEncode(snapshot)),
        'updated_at': YdbTimestamp(stamp),
      },
    );
  }

  Future<void> ensureSchema() async {
    await _createTable(
      _table,
      const TableDescription(
        name: _table,
        columns: [
          ColumnDefinition(name: 'api_key', type: 'Utf8', nullable: false),
          ColumnDefinition(name: 'profile_id', type: 'Utf8', nullable: false),
          ColumnDefinition(
            name: 'snapshot_json',
            type: 'Utf8',
            nullable: false,
          ),
          ColumnDefinition(name: 'updated_at', type: 'Timestamp'),
        ],
        primaryKey: ['api_key', 'profile_id'],
      ),
    );
    await _createTable(
      _locksTable,
      const TableDescription(
        name: _locksTable,
        columns: [
          ColumnDefinition(name: 'api_key', type: 'Utf8', nullable: false),
          ColumnDefinition(name: 'event_id', type: 'Utf8', nullable: false),
          ColumnDefinition(name: 'device_id', type: 'Utf8', nullable: false),
          ColumnDefinition(
            name: 'expires_at',
            type: 'Timestamp',
            nullable: false,
          ),
        ],
        primaryKey: ['api_key', 'event_id'],
      ),
    );
  }

  Future<void> _createTable(String name, TableDescription description) async {
    try {
      await _driver.schemeClient.createTable(name, description);
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('already') ||
          text.contains('exist') ||
          text.contains('schemeerror')) {
        return;
      }
      rethrow;
    }
  }

  Future<QueryResult> _q(
    String yql, [
    Map<String, IYdbValue<dynamic>>? parameters,
  ]) {
    return _driver.queryClient.execute(yql, parameters: parameters);
  }
}

Future<YdbSnapshotClient> openYdbSnapshotClient(
  YdbWorkspaceConnection connection,
) async {
  final fingerprint =
      '${connection.endpoint}|${connection.database}|${connection.secret.hashCode}';
  if (_sharedClient != null && _sharedFingerprint == fingerprint) {
    return _sharedClient!;
  }
  await closeSharedYdbSnapshotClient();
  final config = connection.driverConfig;
  final (credentials, iamTransport) = await ydbCredentialsFromSecret(
    config.accessKey,
  );
  final driver = YdbDriver(
    DriverConfig(
      endpoint: config.endpoint,
      database: config.database,
      credentials: credentials,
      timeout: const Duration(seconds: 20),
    ),
  );
  await driver.initialize();
  final client = YdbSnapshotClient._(driver, iamTransport);
  await client.ensureSchema();
  _sharedClient = client;
  _sharedFingerprint = fingerprint;
  return client;
}

Future<void> closeSharedYdbSnapshotClient() async {
  final client = _sharedClient;
  _sharedClient = null;
  _sharedFingerprint = null;
  await client?.close();
}
