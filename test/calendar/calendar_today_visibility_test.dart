import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_today_visibility.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/state/calendar_navigation_notifier.dart';
import 'package:almanac/state/calendar_toolbar_providers.dart';

void main() {
  final today = DateTime(2026, 7, 22);

  test('isTodayInSelectedWeek is true when today is in selected week', () {
    expect(isTodayInSelectedWeek(DateTime(2026, 7, 20), today), isTrue);
  });

  test(
    'isTodayInSelectedWeek is false when today is outside selected week',
    () {
      expect(isTodayInSelectedWeek(DateTime(2026, 7, 13), today), isFalse);
    },
  );

  group('shouldShowCalendarTodayButton', () {
    test('month mode hides when focused month is current', () {
      final nav = CalendarNavigationState(
        mode: CalendarMode.month,
        focusedMonth: DateTime(2026, 7, 1),
        selectedDate: DateTime(2026, 7, 10),
      );

      expect(
        shouldShowCalendarTodayButton(
          mode: CalendarMode.month,
          nav: nav,
          today: today,
        ),
        isFalse,
      );
    });

    test('month mode shows when focused month differs', () {
      final nav = CalendarNavigationState(
        mode: CalendarMode.month,
        focusedMonth: DateTime(2026, 6, 1),
        selectedDate: DateTime(2026, 6, 10),
      );

      expect(
        shouldShowCalendarTodayButton(
          mode: CalendarMode.month,
          nav: nav,
          today: today,
        ),
        isTrue,
      );
    });

    test('week mode defers to viewState when today is in selected week', () {
      final nav = CalendarNavigationState(
        mode: CalendarMode.week,
        focusedMonth: DateTime(2026, 7, 1),
        selectedDate: DateTime(2026, 7, 20),
      );

      expect(
        shouldShowCalendarTodayButton(
          mode: CalendarMode.week,
          nav: nav,
          today: today,
          viewState: const CalendarToolbarViewState(showToday: true),
        ),
        isTrue,
      );
      expect(
        shouldShowCalendarTodayButton(
          mode: CalendarMode.week,
          nav: nav,
          today: today,
          viewState: const CalendarToolbarViewState(showToday: false),
        ),
        isFalse,
      );
    });

    test('week mode shows when today is outside selected week', () {
      final nav = CalendarNavigationState(
        mode: CalendarMode.week,
        focusedMonth: DateTime(2026, 7, 1),
        selectedDate: DateTime(2026, 7, 6),
      );

      expect(
        shouldShowCalendarTodayButton(
          mode: CalendarMode.week,
          nav: nav,
          today: today,
        ),
        isTrue,
      );
    });
  });
}
