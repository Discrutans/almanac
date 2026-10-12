import 'calendar_types.dart';

/// Ключ календарного дня в локальной зоне (без времени).
DateTime calendarDayKey(DateTime dateTime) {
  final local = dateTime.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Сравнение двух моментов по календарному дню в локальной зоне.
bool isSameCalendarDay(DateTime left, DateTime right) =>
    calendarDayKey(left) == calendarDayKey(right);

/// Понедельник недели, содержащей [date].
DateTime calendarWeekStartMonday(DateTime date) {
  final day = calendarDayKey(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Одна календарная неделя (пн–вс).
bool isSameCalendarWeek(DateTime left, DateTime right) => isSameCalendarDay(
  calendarWeekStartMonday(left),
  calendarWeekStartMonday(right),
);

/// Окно загрузки недельного вида — совпадает с лентой карусели.
abstract final class WeekLoadWindow {
  static const weeksBehind = 8;
  static const weeksAhead = 12;

  static DateTime rangeStart(DateTime selectedDate) {
    final weekStart = calendarWeekStartMonday(selectedDate);
    return weekStart.subtract(const Duration(days: 7 * weeksBehind));
  }

  static DateTime rangeEnd(DateTime selectedDate) {
    final weekStart = calendarWeekStartMonday(selectedDate);
    return weekStart.add(const Duration(days: 7 * (weeksAhead + 1)));
  }
}

/// Кэш индекса по identity списка: rebuild без новых данных не обходит события снова.
final class EventDayIndexCache {
  List<AppEvent>? _events;
  Map<DateTime, List<AppEvent>>? _index;

  Map<DateTime, List<AppEvent>> of(List<AppEvent> events) {
    if (identical(_events, events) && _index != null) return _index!;
    _events = events;
    _index = indexEventsByDay(events);
    return _index!;
  }
}

/// Индекс событий по дню для O(1) lookup в сетках календаря.
///
/// Многодневные события попадают во все затронутые календарные дни.
Map<DateTime, List<AppEvent>> indexEventsByDay(List<AppEvent> events) {
  final map = <DateTime, List<AppEvent>>{};
  for (final event in events) {
    final startDay = calendarDayKey(event.start);
    final endInstant = event.end.isAfter(event.start)
        ? event.end.subtract(const Duration(milliseconds: 1))
        : event.start;
    final endDay = calendarDayKey(endInstant);
    var day = startDay;
    while (true) {
      map.putIfAbsent(day, () => []).add(event);
      if (isSameCalendarDay(day, endDay)) break;
      day = day.add(const Duration(days: 1));
    }
  }
  return map;
}

List<AppEvent> eventsForDay(
  Map<DateTime, List<AppEvent>> index,
  DateTime date,
) {
  return index[calendarDayKey(date)] ?? const [];
}
