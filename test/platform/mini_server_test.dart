@TestOn('vm')
library;

import 'dart:convert';

import 'package:almanac/platform/mini_server/almanac_mini_server.dart';
import 'package:almanac/platform/mini_server/mini_server_ops.dart';
import 'package:almanac/platform/session_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('applySessionOps add and remove', () {
    final start = DateTime.utc(2026, 9, 16, 10);
    final state = applySessionOps(const SessionState(), [
      {
        'op': 'addSlot',
        'slot': {
          'id': 'a',
          'start': start.toIso8601String(),
          'end': start.add(const Duration(hours: 1)).toIso8601String(),
          'label': '10:00',
        },
      },
    ]);
    expect(state.slots, hasLength(1));
    final removed = applySessionOps(state, [
      {'op': 'removeSlot', 'slot_id': 'a'},
    ]);
    expect(removed.slots, isEmpty);
  });

  test('mini server health workspace session and public join', () async {
    final server = AlmanacMiniServer();
    addTearDown(server.stop);
    final info = await server.start(preferredPort: 0);
    final origin = info.loopbackOrigin;
    const key = 'lab-key';
    final headers = {
      'Content-Type': 'application/json',
      'X-Api-Key': key,
      'X-Profile-Id': 'default',
    };

    final health = await http.get(Uri.parse('$origin/health'));
    expect(health.statusCode, 200);
    expect(jsonDecode(health.body)['status'], 'ok');

    final workspace = await http.get(
      Uri.parse('$origin/v1/workspace'),
      headers: headers,
    );
    expect(workspace.statusCode, 200);

    final created = await http.post(
      Uri.parse('$origin/v1/sessions'),
      headers: headers,
      body: jsonEncode({
        'mode': 'collaborative',
        'title': 'Lab',
        'slots': [
          {
            'id': 's1',
            'start': '2026-09-16T10:00:00.000Z',
            'end': '2026-09-16T11:00:00.000Z',
          },
        ],
        'settings': {'max_editors': 3},
        'profile_id': 'default',
      }),
    );
    expect(created.statusCode, 200, reason: created.body);
    final body = jsonDecode(created.body) as Map<String, dynamic>;
    expect(body['title'], 'Lab');
    expect(body['token'], isNotEmpty);
    expect(body['deep_link'], contains('/join/'));

    final token = body['token'] as String;
    final listed = await http.get(
      Uri.parse('$origin/v1/sessions'),
      headers: headers,
    );
    expect(listed.statusCode, 200);
    expect(jsonDecode(listed.body)['sessions'], isNotEmpty);

    final public = await http.get(Uri.parse('$origin/v1/sessions/$token'));
    expect(public.statusCode, 200);
    expect(jsonDecode(public.body)['title'], 'Lab');

    final join = await http.get(Uri.parse('$origin/join/$token'));
    expect(join.statusCode, 200);
    expect(join.body, contains('almanac://join/'));

    final connect = await http.get(
      Uri.parse('$origin/connect?key=lab-key&profile=default'),
    );
    expect(connect.statusCode, 200);
    expect(connect.body, contains('almanac://connect'));

    server.advertisedOrigin = 'https://api.example.com';
    final publicConnect = await http.get(
      Uri.parse('$origin/connect?key=lab-key&profile=default'),
    );
    expect(publicConnect.body, contains('https://api.example.com'));

    final denied = await http.get(Uri.parse('$origin/v1/workspace'));
    expect(denied.statusCode, 401);
  });

  test('mini server event lock exclusive and listed', () async {
    final server = AlmanacMiniServer();
    addTearDown(server.stop);
    final info = await server.start(preferredPort: 0);
    final origin = info.loopbackOrigin;
    const headers = {
      'Content-Type': 'application/json',
      'X-Api-Key': 'lab-key',
    };

    final acquired = await http.post(
      Uri.parse('$origin/v1/calendar/locks'),
      headers: headers,
      body: jsonEncode({
        'event_id': 'evt-1',
        'device_id': 'device-a',
        'ttl_seconds': 90,
      }),
    );
    expect(acquired.statusCode, 200, reason: acquired.body);

    final conflict = await http.post(
      Uri.parse('$origin/v1/calendar/locks'),
      headers: headers,
      body: jsonEncode({'event_id': 'evt-1', 'device_id': 'device-b'}),
    );
    expect(conflict.statusCode, 409);

    final listed = await http.get(
      Uri.parse('$origin/v1/calendar/locks'),
      headers: headers,
    );
    expect(listed.statusCode, 200);
    final locks = jsonDecode(listed.body)['locks'] as List<dynamic>;
    expect(locks.single['event_id'], 'evt-1');
    expect(locks.single['device_id'], 'device-a');
  });
}
