import 'dart:convert';

import '../../data/profiles/profile_kind.dart';
import 'ydb_connection_config.dart';
import 'ydb_workspace_connection.dart';

const ydbInvitePrefix = 'almanac-ydb:1:';

class YdbWorkspaceInvite {
  const YdbWorkspaceInvite({
    required this.connection,
    this.kind = ProfileKind.collaborative,
    this.name,
  });

  final YdbWorkspaceConnection connection;
  final ProfileKind kind;
  final String? name;
}

String encodeYdbInvite(YdbWorkspaceInvite invite) {
  final payload = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'e': invite.connection.endpoint,
        'd': invite.connection.database,
        'k': invite.connection.secret,
        'a': invite.connection.workspaceApiKey,
        'p': invite.connection.workspaceProfileId,
        'kind': invite.kind.name,
        if (invite.name != null && invite.name!.trim().isNotEmpty)
          'n': invite.name!.trim(),
      }),
    ),
  );
  return '$ydbInvitePrefix$payload';
}

String ydbInviteAppLink(YdbWorkspaceInvite invite) {
  return Uri(
    scheme: 'almanac',
    host: 'ydb',
    queryParameters: {'p': encodeYdbInvite(invite)},
  ).toString();
}

YdbWorkspaceInvite? parseYdbInvite(Object raw) {
  if (raw is Uri) return _parseUri(raw);
  return _parseText(raw.toString());
}

YdbWorkspaceInvite? _parseUri(Uri uri) {
  if (uri.scheme == 'almanac' &&
      (uri.host == 'ydb' || uri.host == 'database')) {
    final packed = uri.queryParameters['p'] ?? uri.queryParameters['payload'];
    if (packed != null && packed.trim().isNotEmpty) {
      return _parseText(packed);
    }
  }
  return _parseText(uri.toString());
}

YdbWorkspaceInvite? _parseText(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  if (text.startsWith('almanac://')) {
    return _parseUri(Uri.parse(text));
  }
  if (!text.startsWith(ydbInvitePrefix)) return null;
  try {
    final decoded = utf8.decode(
      base64Url.decode(
        base64Url.normalize(text.substring(ydbInvitePrefix.length)),
      ),
    );
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    final secret = (json['k'] as String? ?? json['secret'] as String? ?? '')
        .trim();
    final database = (json['d'] as String? ?? json['database'] as String? ?? '')
        .trim();
    final apiKey = (json['a'] as String? ?? json['apiKey'] as String? ?? '')
        .trim();
    if (secret.isEmpty || database.isEmpty || apiKey.isEmpty) return null;
    final kindName = json['kind'] as String? ?? ProfileKind.collaborative.name;
    final kind =
        ProfileKind.values.asNameMap()[kindName] ?? ProfileKind.collaborative;
    if (kind == ProfileKind.personal) return null;
    final name = (json['n'] as String? ?? json['name'] as String?)?.trim();
    final endpointRaw =
        (json['e'] as String? ?? json['endpoint'] as String? ?? '').trim();
    final profileRaw =
        (json['p'] as String? ?? json['profile'] as String? ?? 'default')
            .trim();
    return YdbWorkspaceInvite(
      connection: YdbWorkspaceConnection(
        endpoint: endpointRaw.isEmpty
            ? YdbConnectionConfig.defaultEndpoint
            : endpointRaw,
        database: database,
        secret: secret,
        workspaceApiKey: apiKey,
        workspaceProfileId: profileRaw.isEmpty ? 'default' : profileRaw,
        guestKind: kind,
      ),
      kind: kind,
      name: name == null || name.isEmpty ? null : name,
    );
  } catch (_) {
    return null;
  }
}
