import '../../platform/server_url.dart';
import '../../data/profiles/profile_kind.dart';

/// Parsed incoming link to a session (HTTPS or custom scheme).
class SessionDeepLink {
  const SessionDeepLink({required this.token, this.serverOrigin});

  final String token;
  final String? serverOrigin;
}

/// Invite to a host workspace (mini-server / FastAPI), without Yandex JSON.
class WorkspaceInvite {
  const WorkspaceInvite({
    required this.serverOrigin,
    required this.apiKey,
    required this.profileId,
    this.kind = ProfileKind.collaborative,
    this.name,
  });

  final String serverOrigin;
  final String apiKey;
  final String profileId;
  final ProfileKind kind;
  final String? name;
}

/// HTTPS/HTTP landing and `almanac://connect` for guests.
Uri workspaceInviteHttp({
  required String origin,
  required String apiKey,
  required String profileId,
  ProfileKind kind = ProfileKind.collaborative,
  String? name,
}) {
  final base = normalizeServerUrl(origin);
  return Uri.parse('$base/connect').replace(
    queryParameters: {
      'key': apiKey,
      'profile': profileId,
      'kind': kind.name,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    },
  );
}

String workspaceInviteAppLink({
  required String origin,
  required String apiKey,
  required String profileId,
  ProfileKind kind = ProfileKind.collaborative,
  String? name,
}) {
  return Uri(
    scheme: 'almanac',
    host: 'connect',
    queryParameters: {
      'server': normalizeServerUrl(origin),
      'key': apiKey,
      'profile': profileId,
      'kind': kind.name,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    },
  ).toString();
}

WorkspaceInvite? parseWorkspaceInvite(Uri uri) {
  final params = uri.queryParameters;
  final key = (params['key'] ?? params['apiKey'] ?? '').trim();
  if (key.isEmpty) return null;

  var profileId = (params['profile'] ?? params['profileId'] ?? 'default')
      .trim();
  if (profileId.isEmpty) profileId = 'default';

  final kindName = params['kind'] ?? ProfileKind.collaborative.name;
  final kind =
      ProfileKind.values.asNameMap()[kindName] ?? ProfileKind.collaborative;
  if (kind == ProfileKind.personal) return null;

  final name = params['name']?.trim();

  if (uri.scheme == 'almanac' &&
      (uri.host == 'connect' || uri.host == 'workspace')) {
    final server = params['server'];
    if (server == null || server.trim().isEmpty) return null;
    return WorkspaceInvite(
      serverOrigin: normalizeServerUrl(Uri.decodeComponent(server)),
      apiKey: key,
      profileId: profileId,
      kind: kind,
      name: name == null || name.isEmpty ? null : name,
    );
  }

  final segments = uri.pathSegments;
  final isConnectPath =
      segments.isNotEmpty &&
      (segments.first == 'connect' || segments.first == 'workspace');
  if ((uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      isConnectPath) {
    return WorkspaceInvite(
      serverOrigin: normalizeServerUrl('${uri.scheme}://${uri.authority}'),
      apiKey: key,
      profileId: profileId,
      kind: kind,
      name: name == null || name.isEmpty ? null : name,
    );
  }
  return null;
}

/// Extracts session token and optional server origin from a URI.
SessionDeepLink? parseSessionDeepLink(Uri uri) {
  String? serverFromQuery = uri.queryParameters['server'];
  if (serverFromQuery != null && serverFromQuery.isNotEmpty) {
    serverFromQuery = normalizeServerUrl(Uri.decodeComponent(serverFromQuery));
  }

  if (uri.scheme == 'almanac' && uri.host == 'join') {
    final token = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first
        : uri.path.replaceFirst('/', '').split('/').firstOrNull;
    if (token == null || token.isEmpty) return null;
    return SessionDeepLink(token: token, serverOrigin: serverFromQuery);
  }

  final segments = uri.pathSegments;
  if (segments.isEmpty) return null;

  String? token;
  if (segments.length >= 2 &&
      (segments.first == 'join' ||
          segments.first == 'book' ||
          segments.first == 'plan')) {
    token = segments[1];
  } else if (segments.length == 1 &&
      segments.first == 'join' &&
      uri.queryParameters['token'] != null) {
    token = uri.queryParameters['token'];
  }

  if (token == null || token.isEmpty) return null;

  String? serverOrigin = serverFromQuery;
  if (serverOrigin == null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty) {
    serverOrigin = normalizeServerUrl('${uri.scheme}://${uri.authority}');
  }

  return SessionDeepLink(token: token, serverOrigin: serverOrigin);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
