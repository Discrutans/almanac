import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/almanac_http.dart';
import '../../platform/platform_config_repository.dart';
import '../../platform/platform_types.dart';
import '../../platform/server_url.dart';
import '../../platform/ydb/ydb_snapshot_client.dart';
import '../local/local_data_store.dart';
import 'event_lock.dart';

export 'event_lock.dart';

/// Result of taking or skipping an event edit lock.
class EventLockResult {
  const EventLockResult({
    required this.acquired,
    this.skipped = false,
    this.holder,
  });

  final bool acquired;
  final bool skipped;
  final RemoteEventLock? holder;
}

/// Short-lived exclusive lock for one event in a collaborative profile.
final class EventLockService {
  EventLockService({
    required AppConfig config,
    required LocalDataStore store,
    required PlatformConfigRepository platformConfigRepository,
    http.Client? httpClient,
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) : _config = config,
       _store = store,
       _platformConfigRepository = platformConfigRepository,
       _http = almanacHttpClient(inner: httpClient),
       _heartbeatInterval = heartbeatInterval;

  static const ttlSeconds = 90;

  final AppConfig _config;
  final LocalDataStore _store;
  final PlatformConfigRepository _platformConfigRepository;
  final http.Client _http;
  final Duration _heartbeatInterval;

  Timer? _heartbeat;
  String? _heldEventId;
  List<RemoteEventLock> _cachedActive = const [];

  List<RemoteEventLock> get cachedActive => _cachedActive;

  PlatformConfig _connection() {
    final profileId = _store.profileRepository.getActive().id;
    return _platformConfigRepository.getOrCreateConfig(profileId: profileId);
  }

  String get _baseUrl {
    final fromProfile = normalizeServerUrl(_connection().serverBaseUrl);
    if (fromProfile.isNotEmpty) return fromProfile;
    return normalizeServerUrl(_config.serverUrl);
  }

  bool get _useYdb => _store.ydbConnectionStore.isConfigured;

  String deviceId([PlatformConfig? connection]) {
    final config = connection ?? _connection();
    if (config.deviceId.isNotEmpty) return config.deviceId;
    return config.apiKey;
  }

  String get _apiKey {
    final ydb = _store.ydbConnectionStore.active;
    if (ydb != null && ydb.workspaceApiKey.trim().isNotEmpty) {
      return ydb.workspaceApiKey.trim();
    }
    return _connection().apiKey;
  }

  Map<String, String> _headers(String apiKey) {
    return {'Content-Type': 'application/json', 'X-Api-Key': apiKey};
  }

  Uri _lockUri(String eventId, {Map<String, String>? query}) {
    final uri = Uri.parse(
      '$_baseUrl/v1/calendar/locks/${Uri.encodeComponent(eventId)}',
    );
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  bool isLockedByOther(String eventId) {
    final mine = deviceId();
    for (final lock in _cachedActive) {
      if (lock.eventId == eventId && lock.isHeldByOther(mine)) return true;
    }
    return false;
  }

  /// Take the lock for [eventId]. Returns [EventLockResult.acquired] false on conflict.
  Future<EventLockResult> acquire(String eventId) async {
    if (_heldEventId != null && _heldEventId != eventId) {
      await release(_heldEventId);
    }
    if (!_useYdb && _baseUrl.isEmpty) {
      return const EventLockResult(acquired: true, skipped: true);
    }
    final connection = _connection();
    if (_apiKey.isEmpty) {
      return const EventLockResult(acquired: true, skipped: true);
    }
    try {
      final acquired = _useYdb
          ? await _acquireYdb(eventId)
          : await _acquireHttp(eventId, connection);
      if (!acquired) {
        _stopHeartbeat();
        _heldEventId = null;
        await refreshActive();
        RemoteEventLock? holder;
        for (final lock in _cachedActive) {
          if (lock.eventId == eventId) holder = lock;
        }
        return EventLockResult(acquired: false, holder: holder);
      }
      _heldEventId = eventId;
      _startHeartbeat();
      await refreshActive();
      return const EventLockResult(acquired: true);
    } catch (_) {
      _stopHeartbeat();
      _heldEventId = null;
      return const EventLockResult(acquired: false);
    }
  }

  Future<void> release([String? eventId]) async {
    final id = eventId ?? _heldEventId;
    _stopHeartbeat();
    if (_heldEventId == id) {
      _heldEventId = null;
    }
    if (id == null) return;
    if (_apiKey.isEmpty) return;
    try {
      if (_useYdb) {
        final ydb = _store.ydbConnectionStore.active;
        if (ydb == null) return;
        final client = await openYdbSnapshotClient(ydb);
        await client.releaseLock(
          apiKey: _apiKey,
          eventId: id,
          deviceId: deviceId(),
        );
      } else {
        final base = _baseUrl;
        if (base.isEmpty) return;
        await _http.delete(
          _lockUri(id, query: {'device_id': deviceId()}),
          headers: _headers(_apiKey),
        );
      }
    } catch (_) {
      // Best-effort: TTL will expire the lock if the request never arrives.
    }
    await refreshActive();
  }

  Future<List<RemoteEventLock>> refreshActive() async {
    try {
      if (_useYdb) {
        final ydb = _store.ydbConnectionStore.active;
        if (ydb == null) {
          _cachedActive = const [];
          return _cachedActive;
        }
        final client = await openYdbSnapshotClient(ydb);
        _cachedActive = await client.listLocks(apiKey: _apiKey);
        return _cachedActive;
      }
      final base = _baseUrl;
      if (base.isEmpty || _apiKey.isEmpty) {
        _cachedActive = const [];
        return _cachedActive;
      }
      final response = await _http.get(
        Uri.parse('$base/v1/calendar/locks'),
        headers: _headers(_apiKey),
      );
      if (response.statusCode >= 400) {
        _cachedActive = const [];
        return _cachedActive;
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is Map ? decoded['locks'] : decoded;
      if (items is! List) {
        _cachedActive = const [];
        return _cachedActive;
      }
      _cachedActive = [
        for (final item in items)
          if (item is Map)
            RemoteEventLock.fromJson(Map<String, dynamic>.from(item)),
      ];
      return _cachedActive;
    } catch (_) {
      return _cachedActive;
    }
  }

  Future<bool> _acquireYdb(String eventId) async {
    final ydb = _store.ydbConnectionStore.active;
    if (ydb == null) return false;
    final client = await openYdbSnapshotClient(ydb);
    return client.acquireLock(
      apiKey: _apiKey,
      eventId: eventId,
      deviceId: deviceId(),
      ttlSeconds: ttlSeconds,
    );
  }

  Future<bool> _acquireHttp(String eventId, PlatformConfig connection) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/v1/calendar/locks'),
      headers: _headers(connection.apiKey),
      body: jsonEncode({
        'event_id': eventId,
        'device_id': deviceId(connection),
        'ttl_seconds': ttlSeconds,
      }),
    );
    if (response.statusCode == 409 || response.statusCode >= 400) {
      return false;
    }
    return true;
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      unawaited(_heartbeatOnce());
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<void> _heartbeatOnce() async {
    final eventId = _heldEventId;
    if (eventId == null) return;
    try {
      var ok = false;
      if (_useYdb) {
        final ydb = _store.ydbConnectionStore.active;
        if (ydb == null) return;
        final client = await openYdbSnapshotClient(ydb);
        ok = await client.heartbeatLock(
          apiKey: _apiKey,
          eventId: eventId,
          deviceId: deviceId(),
          ttlSeconds: ttlSeconds,
        );
      } else {
        final base = _baseUrl;
        if (base.isEmpty) return;
        final connection = _connection();
        final response = await _http.post(
          Uri.parse(
            '$_baseUrl/v1/calendar/locks/${Uri.encodeComponent(eventId)}/heartbeat',
          ),
          headers: _headers(connection.apiKey),
          body: jsonEncode({
            'device_id': deviceId(connection),
            'ttl_seconds': ttlSeconds,
          }),
        );
        ok = response.statusCode < 400;
      }
      if (!ok) {
        _stopHeartbeat();
        _heldEventId = null;
      }
    } catch (_) {
      // Keep trying on the next tick while the editor is open.
    }
  }
}
