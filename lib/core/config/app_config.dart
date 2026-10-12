/// Конфигурация приложения и удалённого бэкенда.
///
/// Значения можно передать через `--dart-define`:
/// `--dart-define=SERVER_URL=https://your-server.example`
/// `--dart-define=ENABLE_AUTO_REMOTE_SYNC=false` — отключить фоновый push snapshot.
/// `--dart-define=SEED_DEMO_DATA=false` — чистый старт без demo-событий.
class AppConfig {
  const AppConfig({
    required this.serverUrl,
    required this.enableRemoteSync,
    required this.enableAutoRemoteSync,
    required this.pushDeviceToken,
    required this.seedDemoData,
  });

  final String serverUrl;
  final bool enableRemoteSync;
  final bool enableAutoRemoteSync;

  /// Optional FCM token from `--dart-define=PUSH_DEVICE_TOKEN=...`
  final String pushDeviceToken;
  final bool seedDemoData;

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      serverUrl: const String.fromEnvironment('SERVER_URL'),
      enableRemoteSync: const bool.fromEnvironment(
        'ENABLE_REMOTE_SYNC',
        defaultValue: false,
      ),
      enableAutoRemoteSync: const bool.fromEnvironment(
        'ENABLE_AUTO_REMOTE_SYNC',
        defaultValue: true,
      ),
      pushDeviceToken: const String.fromEnvironment('PUSH_DEVICE_TOKEN'),
      seedDemoData: const bool.fromEnvironment(
        'SEED_DEMO_DATA',
        defaultValue: false,
      ),
    );
  }

  bool get hasServer => serverUrl.isNotEmpty;

  bool get remoteSyncEnabled => enableRemoteSync && hasServer;
}
