import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_event_index.dart';
import '../calendar/calendar_month_grid.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import 'app_providers.dart';
import 'calendar_toolbar_providers.dart';

/// Состояние навигации календаря: режим просмотра и выбранные даты.
class CalendarNavigationState {
  const CalendarNavigationState({
    required this.mode,
    required this.focusedMonth,
    required this.selectedDate,
    this.navDirection = 0,
    this.scrollToTodayNonce = 0,
    this.agendaScrollPending = false,
  });

  final CalendarMode mode;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final int navDirection;

  /// Увеличивается при «Сегодня» — прокрутка карусели недели.
  final int scrollToTodayNonce;

  /// Список должен прокрутиться к [selectedDate] и свернуть остальные дни.
  final bool agendaScrollPending;

  CalendarNavigationState copyWith({
    CalendarMode? mode,
    DateTime? focusedMonth,
    DateTime? selectedDate,
    int? navDirection,
    int? scrollToTodayNonce,
    bool? agendaScrollPending,
  }) {
    return CalendarNavigationState(
      mode: mode ?? this.mode,
      focusedMonth: focusedMonth ?? this.focusedMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      navDirection: navDirection ?? this.navDirection,
      scrollToTodayNonce: scrollToTodayNonce ?? this.scrollToTodayNonce,
      agendaScrollPending: agendaScrollPending ?? this.agendaScrollPending,
    );
  }

  /// Диапазон дат, нужный для загрузки событий в текущем режиме.
  ({DateTime start, DateTime end}) visibleRange() {
    switch (mode) {
      case CalendarMode.month:
        final gridDates = monthGridDates(focusedMonth);
        return (
          start: gridDates.first,
          end: gridDates.last.add(const Duration(days: 1)),
        );
      case CalendarMode.week:
        return (
          start: WeekLoadWindow.rangeStart(selectedDate),
          end: WeekLoadWindow.rangeEnd(selectedDate),
        );
      case CalendarMode.agenda:
        final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
        final monthEnd = DateTime(focusedMonth.year, focusedMonth.month + 1, 1);
        return (start: monthStart, end: monthEnd);
      case CalendarMode.year:
        return (
          start: DateTime(focusedMonth.year, 1, 1),
          end: DateTime(focusedMonth.year + 1, 1, 1),
        );
    }
  }

  String headerTitle(AppLocalizations l10n) {
    return switch (mode) {
      CalendarMode.month => l10n.monthYear(
        focusedMonth.month,
        focusedMonth.year,
      ),
      CalendarMode.week => l10n.weekRange(
        calendarWeekStartMonday(selectedDate),
        calendarWeekStartMonday(selectedDate).add(const Duration(days: 6)),
      ),
      CalendarMode.agenda => l10n.monthYear(
        focusedMonth.month,
        focusedMonth.year,
      ),
      CalendarMode.year => '${focusedMonth.year}',
    };
  }

  static DateTime weekStartMonday(DateTime date) =>
      calendarWeekStartMonday(date);

  static DateTime dateOnly(DateTime date) => calendarDayKey(date);
}

/// Управляет переключением месяц/неделя/год и листанием периодов.
class CalendarNavigationNotifier extends Notifier<CalendarNavigationState> {
  @override
  CalendarNavigationState build() {
    final now = DateTime.now();
    final storedMode = calendarModeFromName(
      ref.read(localDataStoreProvider).calendarMode,
    );
    return CalendarNavigationState(
      mode: storedMode ?? CalendarMode.month,
      focusedMonth: DateTime(now.year, now.month, 1),
      selectedDate: CalendarNavigationState.dateOnly(now),
    );
  }

  /// Переключает режим просмотра (месяц / неделя / год).
  void setMode(CalendarMode mode) {
    ref.read(localDataStoreProvider).saveCalendarMode(mode.name);
    clearCalendarToolbarViewStateFromRef(ref);
    final enteringAgenda = mode == CalendarMode.agenda;
    final selected = state.selectedDate;
    state = state.copyWith(
      mode: mode,
      navDirection: 0,
      focusedMonth: enteringAgenda
          ? DateTime(selected.year, selected.month, 1)
          : state.focusedMonth,
      agendaScrollPending: enteringAgenda,
    );
  }

  /// Выбор дня в текущем режиме (без смены month/week/year).
  void selectDate(DateTime date) {
    final day = CalendarNavigationState.dateOnly(date);
    state = state.copyWith(
      selectedDate: day,
      focusedMonth: DateTime(day.year, day.month, 1),
      navDirection: 0,
    );
  }

  /// Явный переход в недельный вид с выбранной датой.
  void openWeekView([DateTime? date]) {
    final day = CalendarNavigationState.dateOnly(date ?? state.selectedDate);
    ref.read(localDataStoreProvider).saveCalendarMode(CalendarMode.week.name);
    clearCalendarToolbarViewStateFromRef(ref);
    state = state.copyWith(
      mode: CalendarMode.week,
      focusedMonth: DateTime(day.year, day.month, 1),
      selectedDate: day,
      navDirection: 0,
    );
  }

  /// Переход в список с выбранной датой у верхнего края.
  void openAgendaView(DateTime date) {
    final day = CalendarNavigationState.dateOnly(date);
    ref.read(localDataStoreProvider).saveCalendarMode(CalendarMode.agenda.name);
    clearCalendarToolbarViewStateFromRef(ref);
    state = state.copyWith(
      mode: CalendarMode.agenda,
      focusedMonth: DateTime(day.year, day.month, 1),
      selectedDate: day,
      navDirection: 0,
      scrollToTodayNonce: state.scrollToTodayNonce + 1,
      agendaScrollPending: true,
    );
  }

  void clearAgendaScrollPending() {
    if (!state.agendaScrollPending) return;
    state = state.copyWith(agendaScrollPending: false);
  }

  void selectMonth(DateTime month) {
    final day = CalendarNavigationState.dateOnly(month);
    ref.read(localDataStoreProvider).saveCalendarMode(CalendarMode.month.name);
    clearCalendarToolbarViewStateFromRef(ref);
    state = state.copyWith(
      mode: CalendarMode.month,
      focusedMonth: DateTime(day.year, day.month, 1),
      selectedDate: day,
      navDirection: 0,
    );
  }

  void previousPeriod() {
    final mode = state.mode;
    if (mode == CalendarMode.month) {
      final month = state.focusedMonth;
      state = state.copyWith(
        navDirection: -1,
        focusedMonth: DateTime(month.year, month.month - 1, 1),
      );
      return;
    }

    if (mode == CalendarMode.week) {
      final selected = CalendarNavigationState.dateOnly(
        state.selectedDate.subtract(const Duration(days: 1)),
      );
      state = state.copyWith(
        navDirection: -1,
        selectedDate: selected,
        focusedMonth: DateTime(selected.year, selected.month, 1),
      );
      return;
    }

    if (mode == CalendarMode.agenda) {
      final month = state.focusedMonth;
      state = state.copyWith(
        navDirection: -1,
        focusedMonth: DateTime(month.year, month.month - 1, 1),
        agendaScrollPending: false,
      );
      return;
    }

    final month = state.focusedMonth;
    state = state.copyWith(
      navDirection: -1,
      focusedMonth: DateTime(month.year - 1, month.month, 1),
    );
  }

  void nextPeriod() {
    final mode = state.mode;
    if (mode == CalendarMode.month) {
      final month = state.focusedMonth;
      state = state.copyWith(
        navDirection: 1,
        focusedMonth: DateTime(month.year, month.month + 1, 1),
      );
      return;
    }

    if (mode == CalendarMode.week) {
      final selected = CalendarNavigationState.dateOnly(
        state.selectedDate.add(const Duration(days: 1)),
      );
      state = state.copyWith(
        navDirection: 1,
        selectedDate: selected,
        focusedMonth: DateTime(selected.year, selected.month, 1),
      );
      return;
    }

    if (mode == CalendarMode.agenda) {
      final month = state.focusedMonth;
      state = state.copyWith(
        navDirection: 1,
        focusedMonth: DateTime(month.year, month.month + 1, 1),
        agendaScrollPending: false,
      );
      return;
    }

    final month = state.focusedMonth;
    state = state.copyWith(
      navDirection: 1,
      focusedMonth: DateTime(month.year + 1, month.month, 1),
    );
  }

  /// С карусели: назад у края сетки месяца — предыдущий месяц.
  void previousMonthFromCarouselEdge() {
    if (state.mode != CalendarMode.week) {
      previousPeriod();
      return;
    }
    final month = state.focusedMonth;
    final prev = DateTime(month.year, month.month - 1, 1);
    final grid = monthGridDates(prev);
    final anchor = grid.last;
    state = state.copyWith(
      navDirection: -1,
      focusedMonth: prev,
      selectedDate: anchor,
    );
  }

  /// С карусели: вперёд у края сетки месяца — следующий месяц.
  void nextMonthFromCarouselEdge() {
    if (state.mode != CalendarMode.week) {
      nextPeriod();
      return;
    }
    final month = state.focusedMonth;
    final next = DateTime(month.year, month.month + 1, 1);
    state = state.copyWith(
      navDirection: 1,
      focusedMonth: next,
      selectedDate: next,
    );
  }

  void goToToday() {
    final today = CalendarNavigationState.dateOnly(DateTime.now());
    state = state.copyWith(
      selectedDate: today,
      focusedMonth: DateTime(today.year, today.month, 1),
      navDirection: 0,
      scrollToTodayNonce: state.scrollToTodayNonce + 1,
      agendaScrollPending: state.mode == CalendarMode.agenda,
    );
  }
}

final calendarNavigationProvider =
    NotifierProvider<CalendarNavigationNotifier, CalendarNavigationState>(
      CalendarNavigationNotifier.new,
    );
