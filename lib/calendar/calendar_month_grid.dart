import 'calendar_event_index.dart';

/// Чистая математика месячной сетки (без UI).
///
/// Используется навигацией, month/year views — без импорта виджетов из state.
List<DateTime> monthGridDates(DateTime month, {int? fixedWeekCount}) {
  final first = DateTime(month.year, month.month, 1);

  final last = DateTime(month.year, month.month + 1, 0);

  final firstGridDay = first.subtract(
    Duration(days: first.weekday - DateTime.monday),
  );

  final leadingDays = first.weekday - DateTime.monday;
  final weekCount =
      fixedWeekCount ?? ((leadingDays + last.day) / 7).ceil().clamp(5, 6);

  return List.generate(
    weekCount * 7,
    (index) => calendarDayKey(firstGridDay.add(Duration(days: index))),
  );
}

/// Фиксированное число недель в мини-календаре годового вида.
const int yearMiniWeekCount = 6;
