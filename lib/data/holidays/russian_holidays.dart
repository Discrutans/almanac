/// Государственный праздник РФ.
class RussianHoliday {
  const RussianHoliday({
    required this.month,
    required this.day,
    required this.name,
    this.isDayOff = true,
  });

  final int month;
  final int day;
  final String name;
  final bool isDayOff;
}

/// Актуальный перечень непереносимых и основных перенесённых дат (2025–2026).
abstract final class RussianHolidays {
  static const List<RussianHoliday> _fixed = [
    RussianHoliday(month: 1, day: 1, name: 'Новый год'),
    RussianHoliday(month: 1, day: 2, name: 'Новогодние каникулы'),
    RussianHoliday(month: 1, day: 3, name: 'Новогодние каникулы'),
    RussianHoliday(month: 1, day: 4, name: 'Новогодние каникулы'),
    RussianHoliday(month: 1, day: 5, name: 'Новогодние каникулы'),
    RussianHoliday(month: 1, day: 6, name: 'Новогодние каникулы'),
    RussianHoliday(month: 1, day: 7, name: 'Рождество Христово'),
    RussianHoliday(month: 1, day: 8, name: 'Новогодние каникулы'),
    RussianHoliday(month: 2, day: 23, name: 'День защитника Отечества'),
    RussianHoliday(month: 3, day: 8, name: 'Международный женский день'),
    RussianHoliday(month: 5, day: 1, name: 'Праздник Весны и Труда'),
    RussianHoliday(month: 5, day: 9, name: 'День Победы'),
    RussianHoliday(month: 6, day: 12, name: 'День России'),
    RussianHoliday(month: 11, day: 4, name: 'День народного единства'),
  ];

  /// Перенесённые выходные по производственному календарю.
  static const Map<int, List<RussianHoliday>> _transferredByYear = {
    2025: [
      RussianHoliday(month: 5, day: 2, name: 'Перенос (майские)'),
      RussianHoliday(month: 12, day: 31, name: 'Перенос (Новый год)'),
    ],
    2026: [
      RussianHoliday(month: 1, day: 9, name: 'Перенос (новогодние)'),
      RussianHoliday(month: 5, day: 11, name: 'Перенос (День Победы)'),
    ],
  };

  static RussianHoliday? onDate(DateTime date) {
    for (final holiday in _fixed) {
      if (holiday.month == date.month && holiday.day == date.day) {
        return holiday;
      }
    }
    for (final holiday
        in _transferredByYear[date.year] ?? const <RussianHoliday>[]) {
      if (holiday.month == date.month && holiday.day == date.day) {
        return holiday;
      }
    }
    return null;
  }

  static List<RussianHoliday> inMonth(DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final result = <RussianHoliday>[];
    for (var day = 1; day <= lastDay; day++) {
      final holiday = onDate(DateTime(month.year, month.month, day));
      if (holiday != null) result.add(holiday);
    }
    return result;
  }
}
