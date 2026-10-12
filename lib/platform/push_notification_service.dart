import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import 'platform_types.dart';

/// Scaffold для FCM/push: регистрация токена на сервере без жёсткой зависимости от Firebase.
abstract final class PushNotificationService {
  static PushNotificationService? _instance;

  static PushNotificationService get instance =>
      _instance ??= _DefaultPushNotificationService();

  /// Инициализация при старте приложения (no-op без Firebase).
  Future<void> initialize();

  /// Текущий push-токен или stable device id для регистрации на backend.
  Future<String?> currentToken({
    required AppConfig config,
    required PlatformConfig platformConfig,
  });

  /// Колбэк при входящем push (обновление pending и т.д.).
  void listen(void Function(String payload) onMessage);
}

final class _DefaultPushNotificationService implements PushNotificationService {
  final _listeners = <void Function(String payload)>{};

  @override
  Future<void> initialize() async {
    if (kDebugMode) {
      debugPrint('PushNotificationService: scaffold ready (no FCM SDK)');
    }
  }

  @override
  Future<String?> currentToken({
    required AppConfig config,
    required PlatformConfig platformConfig,
  }) async {
    if (config.pushDeviceToken.isNotEmpty) return config.pushDeviceToken;
    if (platformConfig.pushToken.isNotEmpty) return platformConfig.pushToken;
    if (platformConfig.deviceId.isNotEmpty) return platformConfig.deviceId;
    return platformConfig.apiKey.isNotEmpty ? platformConfig.apiKey : null;
  }

  @override
  void listen(void Function(String payload) onMessage) {
    _listeners.add(onMessage);
  }
}
