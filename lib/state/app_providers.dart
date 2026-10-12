/// Barrel: базовые app-level Riverpod providers (store, profile, platform, repos).
///
/// Feature-notifiers (`calendar_*`, `pomodoro_*`, `session_*`, …) импортируйте
/// напрямую из своих файлов — так нет циклов `app_providers` ↔ notifier.
library;

export 'core_providers.dart';
export 'platform_providers.dart';
export 'profile_providers.dart';
export 'repository_providers.dart';
