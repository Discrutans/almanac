import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';

/// Обновление Android home widget «Сегодня».
abstract final class TodayHomeWidgetService {
  static const androidWidgetName = 'TodayEventsWidget';
  static const _channel = MethodChannel('com.example.almanac/today_widget');

  static Future<void> updateTodayEvents(List<AppEvent> events) async {
    if (kIsWeb) return;

    final today = DateTime.now();
    final todayEvents = events
        .where((event) => !event.isUndated && event.isOnDate(today))
        .take(5)
        .map((event) => event.noteDisplayTitle)
        .toList();

    final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
    final lines = todayEvents.isEmpty
        ? l10n.todayWidgetEmpty
        : todayEvents.join('\n');

    if (kDebugMode) {
      debugPrint(
        'TodayHomeWidget: ${todayEvents.length} events — $lines',
      );
    }

    try {
      await _channel.invokeMethod<void>('updateToday', {
        'title': l10n.todayWidgetTitle,
        'lines': lines,
      });
    } on MissingPluginException {
      // Desktop / tests without the native channel.
    } catch (error, stackTrace) {
      debugPrint('TodayHomeWidget update failed: $error\n$stackTrace');
    }
  }
}
