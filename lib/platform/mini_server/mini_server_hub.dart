import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../session_types.dart';
import 'mini_server_ops.dart';
import 'mini_server_store.dart';

class MiniServerHub {
  MiniServerHub(this.store);

  final MiniServerStore store;
  final _rooms = <String, Set<WebSocketChannel>>{};

  Future<void> attach({
    required String token,
    required WebSocketChannel channel,
    required String clientId,
    required String displayName,
    String? apiKey,
  }) async {
    final session = store.sessionByToken(token);
    if (session == null) {
      channel.sink.add(
        jsonEncode({'type': 'error', 'message': 'Session not found'}),
      );
      await channel.sink.close(4404);
      return;
    }

    _rooms.putIfAbsent(token, () => {}).add(channel);
    final clients = store.upsertClient(
      token: token,
      clientId: clientId,
      displayName: displayName,
    );
    _send(channel, {
      'type': 'state',
      'version': session.version,
      'session': session.toJson(),
      'clients': clients.map((item) => item.toJson()).toList(),
    });
    broadcast(token, {
      'type': 'presence',
      'clients': clients.map((item) => item.toJson()).toList(),
    }, exclude: channel);

    channel.stream.listen(
      (event) {
        if (event is! String) return;
        unawaited(
          handleMessage(
            token: token,
            channel: channel,
            raw: event,
            apiKey: apiKey,
            clientId: clientId,
          ),
        );
      },
      onDone: () =>
          unawaited(detach(token: token, channel: channel, clientId: clientId)),
      onError: (_) =>
          unawaited(detach(token: token, channel: channel, clientId: clientId)),
    );
  }

  Future<void> detach({
    required String token,
    required WebSocketChannel channel,
    required String clientId,
  }) async {
    final room = _rooms[token];
    room?.remove(channel);
    if (room != null && room.isEmpty) _rooms.remove(token);
    final clients = store.removeClient(token: token, clientId: clientId);
    broadcast(token, {
      'type': 'presence',
      'clients': clients.map((item) => item.toJson()).toList(),
    });
  }

  void broadcast(
    String token,
    Map<String, dynamic> message, {
    WebSocketChannel? exclude,
  }) {
    final room = _rooms[token];
    if (room == null) return;
    final encoded = jsonEncode(message);
    for (final channel in List<WebSocketChannel>.from(room)) {
      if (identical(channel, exclude)) continue;
      try {
        channel.sink.add(encoded);
      } catch (_) {
        room.remove(channel);
      }
    }
  }

  Future<void> handleMessage({
    required String token,
    required WebSocketChannel channel,
    required String raw,
    String? apiKey,
    required String clientId,
  }) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      _send(channel, {'type': 'error', 'message': 'Invalid JSON'});
      return;
    }

    var session = store.sessionByToken(token);
    if (session == null) {
      _send(channel, {'type': 'error', 'message': 'Session not found'});
      return;
    }

    final type = payload['type'] as String?;
    if (type == 'patch') {
      await _handlePatch(
        token: token,
        channel: channel,
        session: session,
        payload: payload,
        apiKey: apiKey,
        clientId: clientId,
      );
      return;
    }

    if (type == 'booking_request') {
      final slotId =
          payload['slotId'] as String? ?? payload['slot_id'] as String?;
      if (slotId == null) {
        _send(channel, {'type': 'error', 'message': 'Slot not found'});
        return;
      }
      final rawFields = payload['fields'] as Map? ?? const {};
      final fields = rawFields.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final request = store.addBookingRequest(
        token: token,
        slotId: slotId,
        fields: fields,
      );
      if (request == null) {
        _send(channel, {
          'type': 'error',
          'message': 'Это время уже занято. Выберите другой слот.',
        });
        return;
      }
      final fresh = store.sessionByToken(token);
      broadcast(token, {
        'type': 'booking_request_created',
        'request': request.toJson(),
        'session': fresh?.toJson(),
      });
      return;
    }

    _send(channel, {'type': 'error', 'message': 'Unknown message type: $type'});
  }

  Future<void> _handlePatch({
    required String token,
    required WebSocketChannel channel,
    required PlatformSession session,
    required Map<String, dynamic> payload,
    String? apiKey,
    required String clientId,
  }) async {
    var state = session.state;
    if (session.mode == SessionMode.collaborative) {
      final settings = Map<String, dynamic>.from(state.settings);
      final maxEditors = _asInt(
        settings['max_editors'],
        fallback: 1,
      ).clamp(1, 20);
      final editors = [
        ...((settings['editors'] as List?) ?? const []).map(
          (item) => item.toString(),
        ),
      ];
      final isOwner = apiKey != null && apiKey == session.workspaceApiKey;
      if (!isOwner) {
        if (!editors.contains(clientId)) {
          if (editors.length >= maxEditors) {
            _send(channel, {
              'type': 'error',
              'message': 'Editor limit reached',
            });
            return;
          }
          editors.add(clientId);
          settings['editors'] = editors;
          state = state.copyWith(settings: settings);
        }
      }
    }

    final ops = <Map<String, dynamic>>[];
    for (final item in payload['ops'] as List? ?? const []) {
      if (item is Map) {
        ops.add(Map<String, dynamic>.from(item));
      }
    }
    final baseVersion =
        payload['baseVersion'] as int? ?? payload['base_version'] as int? ?? 0;
    final updated = store.updateSessionState(
      token: token,
      state: applySessionOps(state, ops),
      expectedVersion: baseVersion,
    );
    if (updated == null) {
      final fresh = store.sessionByToken(token);
      if (fresh != null) {
        _send(channel, {
          'type': 'state',
          'version': fresh.version,
          'session': fresh.toJson(),
          'clients': store.clients(token).map((item) => item.toJson()).toList(),
        });
      }
      return;
    }
    broadcast(token, {
      'type': 'patch_applied',
      'version': updated.version,
      'ops': ops,
      'session': updated.toJson(),
    });
  }

  void _send(WebSocketChannel channel, Map<String, dynamic> message) {
    try {
      channel.sink.add(jsonEncode(message));
    } catch (_) {}
  }

  int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }
}
