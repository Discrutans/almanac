import '../../data/profiles/profile_kind.dart';
import 'ydb_connection_config.dart';

/// Локальные реквизиты YDB workspace. Не попадают в snapshot календаря.
class YdbWorkspaceConnection {
  const YdbWorkspaceConnection({
    required this.endpoint,
    required this.database,
    required this.secret,
    required this.workspaceApiKey,
    this.workspaceProfileId = 'default',
    this.guestKind = ProfileKind.collaborative,
  });

  final String endpoint;
  final String database;
  final String secret;
  final String workspaceApiKey;
  final String workspaceProfileId;

  /// Что получают гости по ссылке: общий календарь или только запись.
  final ProfileKind guestKind;

  bool get isConfigured =>
      database.trim().isNotEmpty &&
      secret.trim().isNotEmpty &&
      workspaceApiKey.trim().isNotEmpty;

  YdbConnectionConfig get driverConfig => YdbConnectionConfig.parse(
    connectionOrPath: database,
    accessKey: secret,
    endpoint: endpoint,
  );

  YdbWorkspaceConnection copyWith({
    String? endpoint,
    String? database,
    String? secret,
    String? workspaceApiKey,
    String? workspaceProfileId,
    ProfileKind? guestKind,
  }) {
    return YdbWorkspaceConnection(
      endpoint: endpoint ?? this.endpoint,
      database: database ?? this.database,
      secret: secret ?? this.secret,
      workspaceApiKey: workspaceApiKey ?? this.workspaceApiKey,
      workspaceProfileId: workspaceProfileId ?? this.workspaceProfileId,
      guestKind: guestKind ?? this.guestKind,
    );
  }

  /// Полный JSON, включая SA. Только для приглашения в памяти, не для файла.
  Map<String, dynamic> toJson() => {
    'endpoint': endpoint,
    'database': database,
    'secret': secret,
    'workspaceApiKey': workspaceApiKey,
    'workspaceProfileId': workspaceProfileId,
    'guestKind': guestKind.name,
  };

  /// Реквизиты без SA JSON — то, что можно писать в `almanac_ydb.json`.
  Map<String, dynamic> toPublicJson() => {
    'endpoint': endpoint,
    'database': database,
    'workspaceApiKey': workspaceApiKey,
    'workspaceProfileId': workspaceProfileId,
    'guestKind': guestKind.name,
  };

  factory YdbWorkspaceConnection.fromJson(Map<String, dynamic> json) {
    final kind = profileKindFromName(
      json['guestKind'] as String? ?? json['kind'] as String?,
      fallback: ProfileKind.collaborative,
    );
    return YdbWorkspaceConnection(
      endpoint:
          json['endpoint'] as String? ?? YdbConnectionConfig.defaultEndpoint,
      database: json['database'] as String? ?? '',
      secret: json['secret'] as String? ?? json['accessKey'] as String? ?? '',
      workspaceApiKey: json['workspaceApiKey'] as String? ?? '',
      workspaceProfileId: json['workspaceProfileId'] as String? ?? 'default',
      guestKind: kind == ProfileKind.personal
          ? ProfileKind.collaborative
          : kind,
    );
  }
}
