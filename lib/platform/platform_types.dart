import '../data/profiles/profile_kind.dart';

/// Тип публичной ссылки Almanac Platform.
enum PublicLinkKind { booking, groupPlan }

/// Настройки API-подключения для профиля (локальный workspace).
class PlatformConfig {
  const PlatformConfig({
    required this.profileId,
    required this.apiKey,
    this.serverBaseUrl = '',
    this.publicOrigin = '',
    this.deviceId = '',
    this.pushToken = '',
    this.autoPush = true,
    this.autoPull = true,
    this.notificationsEnabled = true,
    this.role = ProfileRole.owner,
  });

  final String profileId;
  final String apiKey;

  /// Базовый URL API, например https://api.example.com
  final String serverBaseUrl;

  /// Публичный origin для deep link (/join/:token). Пусто — как Server URL.
  final String publicOrigin;

  /// Stable device id for push registration (FCM token replaces this later).
  final String deviceId;

  /// Optional FCM registration token for server push notifications.
  final String pushToken;

  /// После правок сами отправлять календарь этого профиля.
  final bool autoPush;

  /// Подтягивать обновления этого профиля с сервера в фоне.
  final bool autoPull;

  /// Напоминания о событиях и push заявок для этого профиля.
  final bool notificationsEnabled;

  /// Владелец или участник общего профиля.
  final ProfileRole role;

  PlatformConfig copyWith({
    String? profileId,
    String? apiKey,
    String? serverBaseUrl,
    String? publicOrigin,
    String? deviceId,
    String? pushToken,
    bool? autoPush,
    bool? autoPull,
    bool? notificationsEnabled,
    ProfileRole? role,
  }) {
    return PlatformConfig(
      profileId: profileId ?? this.profileId,
      apiKey: apiKey ?? this.apiKey,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
      publicOrigin: publicOrigin ?? this.publicOrigin,
      deviceId: deviceId ?? this.deviceId,
      pushToken: pushToken ?? this.pushToken,
      autoPush: autoPush ?? this.autoPush,
      autoPull: autoPull ?? this.autoPull,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
    'profileId': profileId,
    'apiKey': apiKey,
    'serverBaseUrl': serverBaseUrl,
    'publicOrigin': publicOrigin,
    'deviceId': deviceId,
    'pushToken': pushToken,
    'autoPush': autoPush,
    'autoPull': autoPull,
    'notificationsEnabled': notificationsEnabled,
    'role': role.name,
  };

  factory PlatformConfig.fromJson(Map<String, dynamic> json) {
    return PlatformConfig(
      profileId: json['profileId'] as String,
      apiKey: json['apiKey'] as String,
      serverBaseUrl: json['serverBaseUrl'] as String? ?? '',
      publicOrigin: json['publicOrigin'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      pushToken: json['pushToken'] as String? ?? '',
      autoPush: json['autoPush'] as bool? ?? true,
      autoPull: json['autoPull'] as bool? ?? true,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      role: profileRoleFromName(json['role'] as String?),
    );
  }
}

/// Публичная ссылка для встраивания или отправки клиентам.
class PublicLinkInfo {
  const PublicLinkInfo({
    required this.kind,
    required this.token,
    required this.title,
    required this.path,
  });

  final PublicLinkKind kind;
  final String token;
  final String title;
  final String path;

  String fullUrl(String origin) {
    final base = origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
    return '$base$path';
  }
}
