import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_event_index.dart';

void main() {
  test('calendarWeekStartMonday returns Monday of the week', () {
    expect(
      calendarWeekStartMonday(DateTime(2026, 7, 22)),
      DateTime(2026, 7, 20),
    );
    expect(
      calendarWeekStartMonday(DateTime(2026, 7, 20)),
      DateTime(2026, 7, 20),
    );
    expect(
      calendarWeekStartMonday(DateTime(2026, 7, 26)),
      DateTime(2026, 7, 20),
    );
  });

  test('isSameCalendarDay compares local calendar days', () {
    expect(
      isSameCalendarDay(
        DateTime(2026, 7, 22, 23, 59),
        DateTime(2026, 7, 22, 0, 1),
      ),
      isTrue,
    );
    expect(
      isSameCalendarDay(DateTime(2026, 7, 22), DateTime(2026, 7, 23)),
      isFalse,
    );
  });
}
