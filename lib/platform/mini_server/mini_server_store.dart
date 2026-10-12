import 'package:uuid/uuid.dart';

import '../session_types.dart';
import 'mini_server_ops.dart';

class CalendarSnapshotRecord {
  const CalendarSnapshotRecord({
    required this.snapshot,
    required this.updatedAt,
  });

  final Map<String, dynamic> snapshot;
  final DateTime updatedAt;
}

class EventLockRecord {
  const EventLockRecord({
    required this.eventId,
    required this.deviceId,
    required this.expiresAt,
  });

  final String eventId;
  final String deviceId;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson({required bool acquired}) => {
    'acquired': acquired,
    'event_id': eventId,
    'device_id': deviceId,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  };
}

/// In-memory workspace for the in-app Platform API.
class MiniServerStore {
  MiniServerStore({this.hostSnapshot});

  /// Host calendar, used until a guest/device POSTs a snapshot.
  Map<String, dynamic>? Function()? hostSnapshot;

  final _sessions = <String, PlatformSession>{};
  final _clients = <String, Map<String, SessionClientPresence>>{};
  final _snapshots = <String, CalendarSnapshotRecord>{};
  final _locks = <String, EventLockRecord>{};
  final _devices = <String, String>{};

  static const _uuid = Uuid();

  Iterable<PlatformSession> sessionsForKey(String apiKey) =>
      _sessions.values.where((session) => session.workspaceApiKey == apiKey);

  PlatformSession? sessionByToken(String token) => _sessions[token];

  PlatformSession createSession({
    required String apiKey,
    required String profileId,
    required SessionMode mode,
    required String title,
    required SessionState state,
  }) {
    final token = _uuid.v4().replaceAll('-', '').substring(0, 16);
    final session = PlatformSession(
      id: _uuid.v4(),
      token: token,
      profileId: profileId,
      mode: mode,
      title: title.trim().isEmpty ? 'Session' : title.trim(),
      state: state,
      version: 1,
      status: SessionStatus.open,
      createdAt: DateTime.now().toUtc(),
      workspaceApiKey: apiKey,
    );
    _sessions[token] = session;
    return session;
  }

  bool closeSession(String token, String apiKey) {
    final session = _sessions[token];
    if (session == null || session.workspaceApiKey != apiKey) return false;
    _sessions[token] = session.copyWith(status: SessionStatus.closed);
    return true;
  }

  PlatformSession? updateSessionState({
    required String token,
    required SessionState state,
    required int expectedVersion,
  }) {
    final session = _sessions[token];
    if (session == null || session.version != expectedVersion) return null;
    final updated = session.copyWith(
      state: state,
      version: session.version + 1,
    );
    _sessions[token] = updated;
    return updated;
  }

  List<SessionClientPresence> upsertClient({
    required String token,
    required String clientId,
    required String displayName,
  }) {
    final room = _clients.putIfAbsent(token, () => {});
    room[clientId] = SessionClientPresence(
      clientId: clientId,
      displayName: displayName,
      lastSeenAt: DateTime.now().toUtc(),
    );
    return room.values.toList();
  }

  List<SessionClientPresence> removeClient({
    required String token,
    required String clientId,
  }) {
    final room = _clients[token];
    if (room == null) return const [];
    room.remove(clientId);
    if (room.isEmpty) _clients.remove(token);
    return room.values.toList();
  }

  List<SessionClientPresence> clients(String token) =>
      _clients[token]?.values.toList() ?? const [];

  SessionBookingRequest? addBookingRequest({
    required String token,
    required String slotId,
    required Map<String, String> fields,
  }) {
    final session = _sessions[token];
    if (session == null) return null;
    if (!session.state.slots.any((slot) => slot.id == slotId)) return null;
    if (isSlotFull(session, slotId)) return null;
    final request = SessionBookingRequest(
      id: _uuid.v4(),
      sessionId: session.id,
      slotId: slotId,
      fields: fields,
      status: SessionBookingRequestStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );
    _sessions[token] = session.copyWith(
      requests: [...session.requests, request],
    );
    return request;
  }

  SessionBookingRequest? decideRequest({
    required String token,
    required String requestId,
    required SessionBookingRequestStatus status,
    required String apiKey,
  }) {
    final session = _sessions[token];
    if (session == null || session.workspaceApiKey != apiKey) return null;
    SessionBookingRequest? target;
    for (final request in session.requests) {
      if (request.id == requestId) target = request;
    }
    if (target == null) return null;
    if (status == SessionBookingRequestStatus.confirmed &&
        isSlotFull(session, target.slotId, excludeRequestId: requestId)) {
      throw StateError('slot_full');
    }
    final updated = SessionBookingRequest(
      id: target.id,
      sessionId: target.sessionId,
      slotId: target.slotId,
      fields: target.fields,
      status: status,
      createdAt: target.createdAt,
    );
    _sessions[token] = session.copyWith(
      requests: [
        for (final request in session.requests)
          if (request.id == requestId) updated else request,
      ],
    );
    return updated;
  }

  CalendarSnapshotRecord? snapshotFor(String apiKey) {
    final stored = _snapshots[apiKey];
    if (stored != null) return stored;
    final host = hostSnapshot?.call();
    if (host == null) return null;
    final updatedRaw = host['updatedAt'] as String?;
    return CalendarSnapshotRecord(
      snapshot: host,
      updatedAt: updatedRaw == null
          ? DateTime.now().toUtc()
          : DateTime.parse(updatedRaw),
    );
  }

  CalendarSnapshotRecord upsertSnapshot({
    required String apiKey,
    required Map<String, dynamic> snapshot,
    List<String>? mergeProfileIds,
  }) {
    var next = snapshot;
    if (mergeProfileIds != null && mergeProfileIds.isNotEmpty) {
      final existing = snapshotFor(apiKey)?.snapshot ?? <String, dynamic>{};
      next = _mergeProfileSlice(existing, snapshot, mergeProfileIds);
    }
    final record = CalendarSnapshotRecord(
      snapshot: next,
      updatedAt: DateTime.now().toUtc(),
    );
    _snapshots[apiKey] = record;
    return record;
  }

  Map<String, dynamic> acquireLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    required int ttlSeconds,
  }) {
    final key = '$apiKey|$eventId';
    final current = _locks[key];
    if (current != null && !current.isExpired && current.deviceId != deviceId) {
      return current.toJson(acquired: false);
    }
    final lock = EventLockRecord(
      eventId: eventId,
      deviceId: deviceId,
      expiresAt: DateTime.now().add(
        Duration(seconds: ttlSeconds.clamp(10, 600)),
      ),
    );
    _locks[key] = lock;
    return lock.toJson(acquired: true);
  }

  Map<String, dynamic>? heartbeatLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
    required int ttlSeconds,
  }) {
    final key = '$apiKey|$eventId';
    final current = _locks[key];
    if (current == null || current.isExpired || current.deviceId != deviceId) {
      return null;
    }
    final lock = EventLockRecord(
      eventId: eventId,
      deviceId: deviceId,
      expiresAt: DateTime.now().add(
        Duration(seconds: ttlSeconds.clamp(10, 600)),
      ),
    );
    _locks[key] = lock;
    return lock.toJson(acquired: true);
  }

  bool releaseLock({
    required String apiKey,
    required String eventId,
    required String deviceId,
  }) {
    final key = '$apiKey|$eventId';
    final current = _locks[key];
    if (current == null || current.deviceId != deviceId) return false;
    _locks.remove(key);
    return true;
  }

  List<Map<String, dynamic>> listLocks({required String apiKey}) {
    final prefix = '$apiKey|';
    return [
      for (final entry in _locks.entries)
        if (entry.key.startsWith(prefix) && !entry.value.isExpired)
          {
            'event_id': entry.value.eventId,
            'device_id': entry.value.deviceId,
            'expires_at': entry.value.expiresAt.toUtc().toIso8601String(),
          },
    ];
  }

  void registerDevice(String apiKey, String token) {
    _devices[apiKey] = token;
  }

  static const _profileMapKeys = [
    'eventsByProfile',
    'schedulesByProfile',
    'templatesByProfile',
    'requestsByProfile',
    'groupPlansByProfile',
    'savingsGoalsByProfile',
    'eventQuickTemplatesByProfile',
    'guestCalendarsByProfile',
    'platformConfigsByProfile',
  ];

  Map<String, dynamic> _mergeProfileSlice(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
    List<String> profileIds,
  ) {
    final merged = Map<String, dynamic>.from(existing);
    final profiles = <String, dynamic>{};
    for (final profile in existing['profiles'] as List? ?? const []) {
      if (profile is Map && profile['id'] != null) {
        profiles[profile['id'].toString()] = profile;
      }
    }
    final wanted = profileIds.toSet();
    for (final profile in incoming['profiles'] as List? ?? const []) {
      if (profile is Map && wanted.contains(profile['id'])) {
        profiles[profile['id'].toString()] = profile;
      }
    }
    if (profiles.isNotEmpty) {
      merged['profiles'] = profiles.values.toList();
    }
    final visible = [
      ...((existing['visibleProfileIds'] as List?) ?? const []).map(
        (item) => item.toString(),
      ),
    ];
    for (final id in profileIds) {
      if (!visible.contains(id)) visible.add(id);
    }
    merged['visibleProfileIds'] = visible;
    for (final key in _profileMapKeys) {
      final current = Map<String, dynamic>.from(
        (existing[key] as Map?) ?? const {},
      );
      final incomingMap = (incoming[key] as Map?) ?? const {};
      for (final id in profileIds) {
        if (incomingMap.containsKey(id)) {
          current[id] = incomingMap[id];
        }
      }
      merged[key] = current;
    }
    return merged;
  }
}
