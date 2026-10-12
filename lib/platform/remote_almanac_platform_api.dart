import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/network/almanac_http.dart';
import '../booking/booking_repository.dart';
import '../booking/booking_types.dart';
import 'almanac_platform_api.dart';
import 'group_plan_types.dart';
import 'platform_config_repository.dart';
import 'platform_types.dart';
import 'server_url.dart';
import 'session_types.dart';
import 'session_websocket_client.dart';

/// HTTP client for the self-hosted Almanac Platform API.
final class RemoteAlmanacPlatformApi implements AlmanacPlatformApi {
  RemoteAlmanacPlatformApi({
    required this.platformConfigRepository,
    required this.baseUrl,
    this.publicOrigin = 'http://localhost:8080',
    http.Client? httpClient,
  }) : _http = almanacHttpClient(inner: httpClient);

  final PlatformConfigRepository platformConfigRepository;
  final String baseUrl;
  final String publicOrigin;
  final http.Client _http;

  String get _normalizedBase {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) return normalizeServerUrl(publicOrigin);
    return normalizeServerUrl(trimmed);
  }

  Map<String, String> _headers({
    required String profileId,
    required String apiKey,
  }) {
    final config = _configFor(profileId);
    final workspaceId = config.profileId.trim().isEmpty
        ? profileId
        : config.profileId;
    return {
      'Content-Type': 'application/json',
      'X-Api-Key': apiKey,
      'X-Profile-Id': workspaceId,
    };
  }

  PlatformConfig _configFor(String profileId) {
    return platformConfigRepository.getOrCreateConfig(profileId: profileId);
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = response.body.trim();
    Map<String, dynamic>? json;
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {
        // Plain-text error bodies (e.g. uvicorn "Internal Server Error").
      }
    }
    if (response.statusCode >= 400) {
      final detail = json?['detail'] ?? (body.isNotEmpty ? body : null);
      throw AlmanacPlatformException(
        detail?.toString() ?? 'HTTP ${response.statusCode}',
      );
    }
    return json ?? <String, dynamic>{};
  }

  @override
  PlatformConfig getWorkspace({required String profileId}) {
    return _configFor(profileId);
  }

  Future<PlatformConfig> verifyWorkspace({required String profileId}) async {
    final config = _configFor(profileId);
    final response = await _http.get(
      Uri.parse('$_normalizedBase/v1/workspace'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
    );
    final json = await _decode(response);
    return config.copyWith(
      profileId: json['profile_id'] as String? ?? profileId,
      serverBaseUrl: _normalizedBase,
    );
  }

  @override
  List<PublicLinkInfo> listPublicLinks({required String profileId}) {
    return [];
  }

  Future<List<PlatformSession>> listSessionsRemote({
    required String profileId,
  }) async {
    final config = _configFor(profileId);
    final response = await _http.get(
      Uri.parse('$_normalizedBase/v1/sessions'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
    );
    final json = await _decode(response);
    final sessions = json['sessions'] as List<dynamic>? ?? const [];
    return sessions
        .map((item) => PlatformSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CreateSessionResult> createSessionRemote({
    required String profileId,
    required SessionMode mode,
    required String title,
    required List<SessionSlot> slots,
    List<SessionFormField> formFields = const [],
    Map<String, dynamic> settings = const {},
  }) async {
    final config = _configFor(profileId);
    platformConfigRepository.updateServerUrl(
      profileId: profileId,
      serverBaseUrl: _normalizedBase,
    );
    final response = await _http.post(
      Uri.parse('$_normalizedBase/v1/sessions'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
      body: jsonEncode({
        'mode': mode.name,
        'title': title,
        'slots': slots.map((slot) => slot.toJson()).toList(),
        'form_fields': formFields.map((field) => field.toJson()).toList(),
        if (settings.isNotEmpty) 'settings': settings,
        'profile_id': config.profileId.trim().isEmpty
            ? profileId
            : config.profileId,
      }),
    );
    final json = await _decode(response);
    return CreateSessionResult.fromJson(json);
  }

  Future<PlatformSession> getSessionRemote(String token) async {
    final response = await _http.get(
      Uri.parse('$_normalizedBase/v1/sessions/$token'),
    );
    final json = await _decode(response);
    return PlatformSession.fromJson(json);
  }

  Future<void> closeSessionRemote({
    required String profileId,
    required String token,
  }) async {
    final config = _configFor(profileId);
    final response = await _http.delete(
      Uri.parse('$_normalizedBase/v1/sessions/$token'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
    );
    await _decode(response);
  }

  Future<SessionBookingRequest> decideBookingRequestRemote({
    required String profileId,
    required String token,
    required String requestId,
    required SessionBookingRequestStatus status,
  }) async {
    final config = _configFor(profileId);
    final response = await _http.patch(
      Uri.parse('$_normalizedBase/v1/sessions/$token/requests/$requestId'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
      body: jsonEncode({'status': status.name}),
    );
    final json = await _decode(response);
    return SessionBookingRequest.fromJson(json);
  }

  Future<void> registerDeviceToken({
    required String profileId,
    required String token,
    String platform = 'flutter',
  }) async {
    final config = _configFor(profileId);
    final response = await _http.post(
      Uri.parse('$_normalizedBase/v1/devices/register'),
      headers: _headers(profileId: profileId, apiKey: config.apiKey),
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    await _decode(response);
  }

  SessionWebSocketClient connectSession({
    required String token,
    String? clientId,
    String displayName = 'Guest',
  }) {
    return SessionWebSocketClient(
      baseUrl: _normalizedBase,
      token: token,
      clientId: clientId,
      displayName: displayName,
    );
  }

  @override
  BookingTemplate createBookingTemplate({
    required String profileId,
    required String title,
    required Duration duration,
    required BookingConfirmationMode confirmationMode,
  }) {
    throw UnsupportedError('Use createSessionRemote with SessionMode.booking');
  }

  @override
  GroupPlan createGroupPlan({
    required String profileId,
    required String title,
    required List<PlanSlot> slots,
    String? notes,
  }) {
    throw UnsupportedError(
      'Use createSessionRemote with SessionMode.collaborative',
    );
  }

  @override
  BookingTemplateLookup? resolveBookingByToken(String token) => null;

  @override
  GroupPlanLookup? resolveGroupPlanByToken(String token) => null;

  @override
  List<BookingSlot> getBookingSlots({
    required String profileId,
    required String templateToken,
    required DateTime day,
  }) {
    return const [];
  }

  @override
  BookingRequest createBookingRequest({
    required String profileId,
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  }) {
    throw UnsupportedError('Use session WebSocket booking_request');
  }

  @override
  PlanVote submitGroupPlanVote({
    required String profileId,
    required String token,
    required String participantName,
    required List<String> slotIds,
  }) {
    throw UnsupportedError('Use session WebSocket patch');
  }
}

class AlmanacPlatformException implements Exception {
  AlmanacPlatformException(this.message);

  final String message;

  @override
  String toString() => message;
}
