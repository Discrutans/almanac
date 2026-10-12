import 'package:almanac/calendar/calendar_month_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('monthGridDates', () {
    test('starts on Monday and covers focused month', () {
      // July 2026 starts on Wednesday → grid starts Mon Jun 29.
      final dates = monthGridDates(DateTime(2026, 7, 1));
      expect(dates.first.weekday, DateTime.monday);
      expect(dates.first, DateTime(2026, 6, 29));
      expect(
        dates.any((d) => d.year == 2026 && d.month == 7 && d.day == 1),
        isTrue,
      );
      expect(
        dates.any((d) => d.year == 2026 && d.month == 7 && d.day == 31),
        isTrue,
      );
      expect(dates.length % 7, 0);
      expect(dates.length ~/ 7, inInclusiveRange(5, 6));
    });

    test('fixedWeekCount pins year mini grid to 6 weeks', () {
      final dates = monthGridDates(
        DateTime(2026, 2, 1),
        fixedWeekCount: yearMiniWeekCount,
      );
      expect(dates.length, yearMiniWeekCount * 7);
    });
  });
}
