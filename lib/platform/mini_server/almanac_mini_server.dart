import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';

import '../session_types.dart';
import '../server_url.dart';
import '../../core/router/deep_link.dart';
import '../../data/profiles/profile_kind.dart';
import 'mini_server_hub.dart';
import 'mini_server_lan.dart';
import 'mini_server_store.dart';

class MiniServerInfo {
  const MiniServerInfo({
    required this.port,
    required this.loopbackOrigin,
    required this.lanOrigin,
    required this.lanIps,
  });

  final int port;
  final String loopbackOrigin;
  final String lanOrigin;
  final List<String> lanIps;
}

/// In-process Platform API: тот же контракт, что FastAPI `/v1`.
class AlmanacMiniServer {
  AlmanacMiniServer({MiniServerStore? store})
    : store = store ?? MiniServerStore();

  final MiniServerStore store;
  late final MiniServerHub hub = MiniServerHub(store);

  HttpServer? _http;
  MiniServerInfo? _info;
  String advertisedOrigin = '';

  MiniServerInfo? get info => _info;
  bool get isRunning => _http != null;

  String get publicOrigin {
    final advertised = advertisedOrigin.trim();
    if (advertised.isNotEmpty) return normalizeServerUrl(advertised);
    return _info?.lanOrigin ?? _info?.loopbackOrigin ?? '';
  }

  Future<MiniServerInfo> start({int preferredPort = 8080}) async {
    if (_http != null && _info != null) return _info!;

    HttpServer? bound;
    Object? lastError;
    for (final port in [preferredPort, 4780, 0]) {
      try {
        bound = await shelf_io.serve(
          _pipeline(),
          InternetAddress.anyIPv4,
          port,
        );
        break;
      } on SocketException catch (error) {
        lastError = error;
      }
    }
    if (bound == null) {
      throw StateError('Не удалось открыть порт ($lastError)');
    }
    _http = bound;
    final lanIps = await lanIPv4Addresses();
    final lan = lanIps.isEmpty ? '127.0.0.1' : lanIps.first;
    _info = MiniServerInfo(
      port: bound.port,
      loopbackOrigin: 'http://127.0.0.1:${bound.port}',
      lanOrigin: 'http://$lan:${bound.port}',
      lanIps: lanIps,
    );
    return _info!;
  }

  Future<void> stop() async {
    await _http?.close(force: true);
    _http = null;
    _info = null;
  }

  Handler _pipeline() {
    return const Pipeline().addMiddleware(_cors()).addHandler(_dispatch);
  }

  FutureOr<Response> _dispatch(Request request) {
    if (_isWebSocketUpgrade(request) &&
        request.url.path.startsWith('v1/ws/sessions/')) {
      return _webSocket(request);
    }
    return _router()(request);
  }

  bool _isWebSocketUpgrade(Request request) {
    final upgrade = request.headers['upgrade']?.toLowerCase();
    return request.method == 'GET' && upgrade == 'websocket';
  }

  FutureOr<Response> _webSocket(Request request) {
    final token = request.url.path.split('/').last;
    final params = request.url.queryParameters;
    final clientId = params['clientId'] ?? const Uuid().v4();
    final name = params['name'] ?? 'Guest';
    final apiKey = params['apiKey'];
    return webSocketHandler((channel, _) {
      unawaited(
        hub.attach(
          token: token,
          channel: channel,
          clientId: clientId,
          displayName: name,
          apiKey: apiKey,
        ),
      );
    })(request);
  }

  Router _router() {
    final router = Router()
      ..options('/<ignored|.*>', _options)
      ..get('/health', (_) => _json({'status': 'ok'}))
      ..get('/v1/workspace', _workspace)
      ..get('/v1/sessions', _listSessions)
      ..post('/v1/sessions', _createSession)
      ..get('/v1/sessions/<token>', _getSession)
      ..delete('/v1/sessions/<token>', _deleteSession)
      ..patch('/v1/sessions/<token>/requests/<requestId>', _decideRequest)
      ..get('/v1/calendar/snapshot', _getSnapshot)
      ..post('/v1/calendar/snapshot', _postSnapshot)
      ..post('/v1/calendar/locks', _acquireLock)
      ..get('/v1/calendar/locks', _listLocks)
      ..post('/v1/calendar/locks/<eventId>/heartbeat', _heartbeatLock)
      ..delete('/v1/calendar/locks/<eventId>', _releaseLock)
      ..post('/v1/devices/register', _registerDevice)
      ..get('/join/<token>', _joinPage)
      ..get('/connect', _connectPage)
      ..get('/', _homePage);
    return router;
  }

  Response _options(Request request) => Response(204, headers: _corsHeaders);

  Future<Response> _workspace(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final profileId = request.headers['x-profile-id'] ?? 'default';
    final origin = publicOrigin;
    return _json({
      'profile_id': profileId,
      'api_key': key,
      'public_origin': origin,
    });
  }

  Future<Response> _listSessions(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    return _json({
      'sessions': [
        for (final session in store.sessionsForKey(key as String))
          session.toJson(),
      ],
    });
  }

  Future<Response> _createSession(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    final modeName = body['mode'] as String? ?? 'collaborative';
    final session = store.createSession(
      apiKey: key as String,
      profileId: body['profile_id'] as String? ?? 'default',
      mode: SessionMode.values.byName(modeName),
      title: body['title'] as String? ?? 'Session',
      state: SessionState.fromJson({
        'slots': body['slots'] ?? const [],
        'form_fields': body['form_fields'] ?? const [],
        'settings': body['settings'] ?? const {},
      }),
    );
    final origin = publicOrigin;
    return _json({
      'id': session.id,
      'token': session.token,
      'deep_link': '$origin/join/${session.token}',
      'mode': session.mode.name,
      'title': session.title,
    });
  }

  Response _getSession(Request request, String token) {
    final session = store.sessionByToken(token);
    if (session == null) {
      return _json({'detail': 'Session not found'}, status: 404);
    }
    return _json(session.toJson());
  }

  Response _deleteSession(Request request, String token) {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final closed = store.closeSession(token, key as String);
    if (!closed) return _json({'detail': 'Session not found'}, status: 404);
    return _json({'ok': true});
  }

  Future<Response> _decideRequest(
    Request request,
    String token,
    String requestId,
  ) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    final statusName = body['status'] as String? ?? '';
    if (statusName != 'confirmed' && statusName != 'rejected') {
      return _json({
        'detail': 'Status must be confirmed or rejected',
      }, status: 400);
    }
    try {
      final updated = store.decideRequest(
        token: token,
        requestId: requestId,
        status: SessionBookingRequestStatus.values.byName(statusName),
        apiKey: key as String,
      );
      if (updated == null) {
        return _json({'detail': 'Request not found'}, status: 404);
      }
      final fresh = store.sessionByToken(token);
      hub.broadcast(token, {
        'type': 'booking_request_decided',
        'requestId': updated.id,
        'status': updated.status.name,
        'request': updated.toJson(),
        'session': fresh?.toJson(),
      });
      return _json(updated.toJson());
    } on StateError {
      return _json({
        'detail': 'Slot is full — cannot confirm this request',
      }, status: 409);
    }
  }

  Response _getSnapshot(Request request) {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final record = store.snapshotFor(key as String);
    return _json({
      'profile_id': 'default',
      'snapshot': record?.snapshot,
      'updated_at': record?.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<Response> _postSnapshot(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    final snapshot = Map<String, dynamic>.from(
      body['snapshot'] as Map? ?? const {},
    );
    final merge = (body['merge_profile_ids'] as List?)
        ?.map((item) => item.toString())
        .toList();
    final record = store.upsertSnapshot(
      apiKey: key as String,
      snapshot: snapshot,
      mergeProfileIds: merge,
    );
    return _json({
      'profile_id': body['profile_id'] ?? 'default',
      'snapshot': record.snapshot,
      'updated_at': record.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<Response> _acquireLock(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    final result = store.acquireLock(
      apiKey: key as String,
      eventId: body['event_id'] as String? ?? '',
      deviceId: body['device_id'] as String? ?? '',
      ttlSeconds: (body['ttl_seconds'] as num?)?.toInt() ?? 90,
    );
    final acquired = result['acquired'] == true;
    return _json(result, status: acquired ? 200 : 409);
  }

  Response _listLocks(Request request) {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    return _json({'locks': store.listLocks(apiKey: key as String)});
  }

  Future<Response> _heartbeatLock(Request request, String eventId) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    final result = store.heartbeatLock(
      apiKey: key as String,
      eventId: eventId,
      deviceId: body['device_id'] as String? ?? '',
      ttlSeconds: (body['ttl_seconds'] as num?)?.toInt() ?? 90,
    );
    if (result == null) {
      return _json({'detail': 'lock_not_held'}, status: 409);
    }
    return _json(result);
  }

  Response _releaseLock(Request request, String eventId) {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final deviceId = request.url.queryParameters['device_id'] ?? '';
    final released = store.releaseLock(
      apiKey: key as String,
      eventId: eventId,
      deviceId: deviceId,
    );
    return _json({'released': released});
  }

  Future<Response> _registerDevice(Request request) async {
    final key = _requireApiKey(request);
    if (key is Response) return key;
    final body = await _readJson(request);
    store.registerDevice(key as String, body['token'] as String? ?? '');
    return _json({'ok': true});
  }

  Response _joinPage(Request request, String token) {
    final origin = publicOrigin;
    final appLink =
        'almanac://join/$token?server=${Uri.encodeComponent(origin)}';
    final html =
        '''
<!DOCTYPE html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Almanac</title></head>
<body style="font-family:system-ui;max-width:40rem;margin:3rem auto;padding:0 1rem">
<h1>Almanac</h1>
<p>Сессия <code>$token</code></p>
<p><a href="$appLink">Открыть в Almanac</a></p>
<p>Или вставьте Server URL <code>$origin</code> в «Ссылки и API».</p>
</body></html>
''';
    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Response _homePage(Request request) {
    final origin = publicOrigin;
    final html =
        '''
<!DOCTYPE html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Almanac mini-server</title></head>
<body style="font-family:system-ui;max-width:40rem;margin:3rem auto;padding:0 1rem">
<h1>Almanac</h1>
<p>Мини-сервер запущен. Health: <a href="/health">/health</a></p>
<p>Гостевая ссылка на workspace выдаёт хозяин в приложении: «Ссылки и API».</p>
<p>Этот адрес: <code>$origin</code></p>
</body></html>
''';
    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Response _connectPage(Request request) {
    final origin = publicOrigin;
    final key = request.url.queryParameters['key'] ?? '';
    final profile = request.url.queryParameters['profile'] ?? 'default';
    final kindName =
        request.url.queryParameters['kind'] ?? ProfileKind.collaborative.name;
    final kind =
        ProfileKind.values.asNameMap()[kindName] ?? ProfileKind.collaborative;
    final name = request.url.queryParameters['name'];
    final appLink = workspaceInviteAppLink(
      origin: origin,
      apiKey: key,
      profileId: profile,
      kind: kind,
      name: name,
    );
    final html =
        '''
<!DOCTYPE html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Almanac</title></head>
<body style="font-family:system-ui;max-width:40rem;margin:3rem auto;padding:0 1rem">
<h1>Almanac</h1>
<p>Приглашение в общий календарь. JSON Яндекса не нужен.</p>
<p><a href="$appLink">Открыть в Almanac</a></p>
<p>Server URL: <code>$origin</code><br>Profile ID: <code>$profile</code></p>
</body></html>
''';
    return Response.ok(
      html,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Object _requireApiKey(Request request) {
    final key = request.headers['x-api-key']?.trim() ?? '';
    if (key.isEmpty) {
      return _json({'detail': 'Missing X-Api-Key header'}, status: 401);
    }
    return key;
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final raw = await request.readAsString();
    if (raw.trim().isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  Response _json(Object body, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: {
        'content-type': 'application/json; charset=utf-8',
        ..._corsHeaders,
      },
    );
  }

  Middleware _cors() {
    return (inner) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response(204, headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,PATCH,DELETE,OPTIONS',
  };
}
