import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'session_types.dart';
import 'server_url.dart';

typedef SessionMessageHandler = void Function(Map<String, dynamic> message);

/// WebSocket client for real-time session sync.
class SessionWebSocketClient {
  SessionWebSocketClient({
    required this.baseUrl,
    required this.token,
    String? clientId,
    this.displayName = 'Guest',
    this.apiKey,
  }) : clientId = clientId ?? const Uuid().v4();

  final String baseUrl;
  final String token;
  final String clientId;
  final String displayName;
  final String? apiKey;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  PlatformSession? session;
  int version = 0;
  List<SessionClientPresence> clients = const [];

  Uri _wsUri() {
    final wsBase = serverUrlToWebSocketBase(baseUrl);
    final query = <String, String>{'clientId': clientId, 'name': displayName};
    if (apiKey != null && apiKey!.isNotEmpty) {
      query['apiKey'] = apiKey!;
    }
    return Uri.parse(
      '$wsBase/v1/ws/sessions/$token',
    ).replace(queryParameters: query);
  }

  Future<void> connect() async {
    await disconnect();
    _channel = WebSocketChannel.connect(_wsUri());
    _subscription = _channel!.stream.listen((event) {
      final payload = jsonDecode(event as String) as Map<String, dynamic>;
      _handleMessage(payload);
      _messageController.add(payload);
    }, onError: _messageController.addError);
  }

  void _handleMessage(Map<String, dynamic> payload) {
    final type = payload['type'] as String?;
    if (type == 'state' || type == 'patch_applied') {
      final sessionJson = payload['session'] as Map<String, dynamic>?;
      if (sessionJson != null) {
        session = PlatformSession.fromJson(sessionJson);
        version = payload['version'] as int? ?? session!.version;
      }
      final clientsJson = payload['clients'] as List<dynamic>?;
      if (clientsJson != null) {
        clients = clientsJson
            .map(
              (item) =>
                  SessionClientPresence.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    }
    if (type == 'presence') {
      final clientsJson = payload['clients'] as List<dynamic>? ?? const [];
      clients = clientsJson
          .map(
            (item) =>
                SessionClientPresence.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }
    if (type == 'booking_request_created' ||
        type == 'booking_request_decided') {
      final sessionJson = payload['session'] as Map<String, dynamic>?;
      if (sessionJson != null) {
        session = PlatformSession.fromJson(sessionJson);
        version = session!.version;
      } else {
        _mergeBookingRequestEvent(payload);
      }
    }
  }

  void _mergeBookingRequestEvent(Map<String, dynamic> payload) {
    final requestJson = payload['request'] as Map<String, dynamic>?;
    if (requestJson == null || session == null) return;

    final updated = SessionBookingRequest.fromJson(requestJson);
    final requests = session!.requests
        .map((request) => request.id == updated.id ? updated : request)
        .toList();
    if (!requests.any((request) => request.id == updated.id)) {
      requests.add(updated);
    }
    session = session!.copyWith(requests: requests);
  }

  Future<void> sendPatch({required List<Map<String, dynamic>> ops}) async {
    _channel?.sink.add(
      jsonEncode({'type': 'patch', 'baseVersion': version, 'ops': ops}),
    );
  }

  Future<void> sendBookingRequest({
    required String slotId,
    required Map<String, String> fields,
  }) async {
    _channel?.sink.add(
      jsonEncode({
        'type': 'booking_request',
        'slotId': slotId,
        'fields': fields,
      }),
    );
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
  }
}
