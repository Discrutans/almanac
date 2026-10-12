import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/calendar_month_grid.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:almanac/state/calendar_navigation_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late LocalDataStore store;

  setUp(() async {
    store = await LocalDataStore.openInMemory();
  });

  ProviderContainer testContainer() {
    return ProviderContainer(
      overrides: [localDataStoreProvider.overrideWithValue(store)],
    );
  }

  test('selectDate keeps current mode and updates selected day', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.month,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 1),
    );

    notifier.selectDate(DateTime(2026, 3, 15));

    final state = container.read(calendarNavigationProvider);
    expect(state.mode, CalendarMode.month);
    expect(state.selectedDate, DateTime(2026, 3, 15));
    expect(state.focusedMonth, DateTime(2026, 3, 1));
  });

  test('openWeekView switches to week mode', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.month,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 1),
    );

    notifier.openWeekView(DateTime(2026, 3, 15));

    final state = container.read(calendarNavigationProvider);
    expect(state.mode, CalendarMode.week);
    expect(state.selectedDate, DateTime(2026, 3, 15));
    expect(store.calendarMode, CalendarMode.week.name);
  });

  test('openAgendaView switches to agenda and scrolls to selected day', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 7, 1),
      selectedDate: DateTime(2026, 7, 14),
    );

    notifier.openAgendaView(DateTime(2026, 7, 16));

    final state = container.read(calendarNavigationProvider);
    expect(state.mode, CalendarMode.agenda);
    expect(state.selectedDate, DateTime(2026, 7, 16));
    expect(state.focusedMonth, DateTime(2026, 7, 1));
    expect(state.scrollToTodayNonce, 1);
    expect(state.agendaScrollPending, isTrue);
    expect(store.calendarMode, CalendarMode.agenda.name);
  });

  test('setMode to agenda scrolls to selected date', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 7, 1),
      selectedDate: DateTime(2026, 7, 16),
    );

    notifier.setMode(CalendarMode.agenda);

    final state = container.read(calendarNavigationProvider);
    expect(store.calendarMode, CalendarMode.agenda.name);
    expect(state.mode, CalendarMode.agenda);
    expect(state.selectedDate, DateTime(2026, 7, 16));
    expect(state.focusedMonth, DateTime(2026, 7, 1));
    expect(state.agendaScrollPending, isTrue);
  });

  test('previousPeriod moves month back in month mode', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.month,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 10),
    );

    notifier.previousPeriod();

    final state = container.read(calendarNavigationProvider);
    expect(state.focusedMonth, DateTime(2026, 2, 1));
    expect(state.navDirection, -1);
  });

  test('week visible range covers neighboring weeks around selection', () {
    final sunday = DateTime(2026, 6, 28);
    final nav = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 6, 1),
      selectedDate: sunday,
    );
    final range = nav.visibleRange();

    expect(range.start, WeekLoadWindow.rangeStart(sunday));
    expect(range.end, WeekLoadWindow.rangeEnd(sunday));
    expect(sunday.isBefore(range.end), isTrue);
    expect(
      sunday.isAfter(range.start.subtract(const Duration(days: 1))),
      isTrue,
    );
  });

  test('goToToday keeps current mode and selects today', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.year,
      focusedMonth: DateTime(2020, 1, 1),
      selectedDate: DateTime(2020, 1, 1),
    );

    notifier.goToToday();

    final state = container.read(calendarNavigationProvider);
    final today = CalendarNavigationState.dateOnly(DateTime.now());
    expect(state.mode, CalendarMode.year);
    expect(state.selectedDate, today);
    expect(state.scrollToTodayNonce, 1);
    expect(state.agendaScrollPending, isFalse);

    notifier.goToToday();
    expect(container.read(calendarNavigationProvider).scrollToTodayNonce, 2);
  });

  test('goToToday sets agenda scroll pending in agenda mode', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.agenda,
      focusedMonth: DateTime(2020, 1, 1),
      selectedDate: DateTime(2020, 1, 1),
    );

    notifier.goToToday();

    final state = container.read(calendarNavigationProvider);
    expect(state.mode, CalendarMode.agenda);
    expect(state.agendaScrollPending, isTrue);
  });

  test('clearAgendaScrollPending clears pending flag', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.agenda,
      focusedMonth: DateTime(2026, 7, 1),
      selectedDate: DateTime(2026, 7, 14),
      agendaScrollPending: true,
    );

    notifier.clearAgendaScrollPending();

    expect(
      container.read(calendarNavigationProvider).agendaScrollPending,
      isFalse,
    );
  });

  test('previousPeriod moves week back one day in week mode', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 10),
    );

    notifier.previousPeriod();

    final state = container.read(calendarNavigationProvider);
    expect(state.selectedDate, DateTime(2026, 3, 9));
    expect(state.navDirection, -1);
  });

  test('nextPeriod moves week forward one day in week mode', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 10),
    );

    notifier.nextPeriod();

    final state = container.read(calendarNavigationProvider);
    expect(state.selectedDate, DateTime(2026, 3, 11));
    expect(state.navDirection, 1);
  });

  test('previousMonthFromCarouselEdge moves to previous month', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 9),
    );

    notifier.previousMonthFromCarouselEdge();

    final state = container.read(calendarNavigationProvider);
    expect(state.focusedMonth, DateTime(2026, 2, 1));
    expect(state.selectedDate, monthGridDates(DateTime(2026, 2, 1)).last);
    expect(state.navDirection, -1);
  });

  test('nextMonthFromCarouselEdge moves to next month', () {
    final container = testContainer();
    addTearDown(container.dispose);

    final notifier = container.read(calendarNavigationProvider.notifier);
    notifier.state = CalendarNavigationState(
      mode: CalendarMode.week,
      focusedMonth: DateTime(2026, 3, 1),
      selectedDate: DateTime(2026, 3, 15),
    );

    notifier.nextMonthFromCarouselEdge();

    final state = container.read(calendarNavigationProvider);
    expect(state.focusedMonth, DateTime(2026, 4, 1));
    expect(state.selectedDate, DateTime(2026, 4, 1));
    expect(state.navDirection, 1);
  });
}
