import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_event_index.dart';
import '../calendar/calendar_types.dart';
import 'calendar_filter_providers.dart';

typedef AgendaMonthKey = String;
typedef AgendaDayKey = String;

String agendaMonthKey(DateTime month) => '${month.year}-${month.month}';

String agendaDayKey(DateTime date) {
  final day = calendarDayKey(date);
  return '${day.year}-${day.month}-${day.day}';
}

List<DateTime> agendaMonthDates(DateTime focusedMonth) {
  final lastDay = DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
  return [
    for (var day = 1; day <= lastDay; day++)
      DateTime(focusedMonth.year, focusedMonth.month, day),
  ];
}

List<DateTime> agendaDaysWithEventsForMonth(
  List<AppEvent> events,
  DateTime focusedMonth, {
  Map<DateTime, List<AppEvent>>? eventsIndex,
}) {
  final index = eventsIndex ?? indexEventsByDay(events);
  return agendaMonthDates(focusedMonth)
      .where((date) => eventsForDay(index, date).isNotEmpty)
      .toList(growable: false);
}

/// Дни в списке agenda: дни с событиями + сегодня и [highlightDay] в месяце.
List<DateTime> agendaVisibleDays(
  List<AppEvent> events,
  DateTime focusedMonth, {
  DateTime? today,
  DateTime? highlightDay,
  Set<int> colorFilter = const {},
  Map<DateTime, List<AppEvent>>? eventsIndex,
}) {
  final index = eventsIndex ?? indexEventsByDay(events);

  final daysWithEvents =
      agendaDaysWithEventsForMonth(events, focusedMonth, eventsIndex: index)
          .where((date) {
            if (colorFilter.isEmpty) return true;
            return dayHasVisibleEventsForColorFilter(
              eventsForDay(index, date),
              colorFilter,
            );
          })
          .toList(growable: false);

  final extras = <DateTime>[];

  void maybeAdd(DateTime day) {
    final normalized = calendarDayKey(day);
    if (focusedMonth.year != normalized.year ||
        focusedMonth.month != normalized.month) {
      return;
    }
    if (daysWithEvents.any((entry) => isSameCalendarDay(entry, normalized))) {
      return;
    }
    if (extras.any((entry) => isSameCalendarDay(entry, normalized))) {
      return;
    }
    extras.add(normalized);
  }

  maybeAdd(today ?? DateTime.now());
  if (highlightDay != null) {
    maybeAdd(highlightDay);
  }

  if (extras.isEmpty) return daysWithEvents;
  return [...daysWithEvents, ...extras]..sort((a, b) => a.compareTo(b));
}

@immutable
class AgendaCollapseState {
  const AgendaCollapseState({this.collapsedByMonth = const {}});

  final Map<AgendaMonthKey, Set<AgendaDayKey>> collapsedByMonth;
}

class AgendaCollapseNotifier extends Notifier<AgendaCollapseState> {
  @override
  AgendaCollapseState build() => const AgendaCollapseState();

  Set<AgendaDayKey> collapsedDaysForMonth(AgendaMonthKey monthKey) =>
      state.collapsedByMonth[monthKey] ?? const {};

  bool isDayCollapsed(AgendaMonthKey monthKey, DateTime date) =>
      collapsedDaysForMonth(monthKey).contains(agendaDayKey(date));

  bool areAllExpanded(AgendaMonthKey monthKey, Iterable<DateTime> days) {
    final collapsed = collapsedDaysForMonth(monthKey);
    return days.every((day) => !collapsed.contains(agendaDayKey(day)));
  }

  void toggleDay(AgendaMonthKey monthKey, DateTime date) {
    final dayKey = agendaDayKey(date);
    final next = {...collapsedDaysForMonth(monthKey)};
    if (next.contains(dayKey)) {
      next.remove(dayKey);
    } else {
      next.add(dayKey);
    }
    _setMonth(monthKey, next);
  }

  void toggleCollapseAll(AgendaMonthKey monthKey, Iterable<DateTime> days) {
    final dayKeys = days.map(agendaDayKey).toSet();
    if (dayKeys.isEmpty) return;

    final collapsed = collapsedDaysForMonth(monthKey);
    final allExpanded = dayKeys.every((key) => !collapsed.contains(key));
    _setMonth(monthKey, allExpanded ? dayKeys : {});
  }

  void focusDayOnly(
    AgendaMonthKey monthKey,
    Iterable<DateTime> days,
    DateTime date,
  ) {
    final focusKey = agendaDayKey(date);
    final dayKeys = days.map(agendaDayKey).toSet();
    if (!dayKeys.contains(focusKey)) {
      _setMonth(monthKey, {});
      return;
    }
    _setMonth(monthKey, dayKeys.where((key) => key != focusKey).toSet());
  }

  void focusTodayOnly(AgendaMonthKey monthKey, Iterable<DateTime> days) {
    focusDayOnly(monthKey, days, DateTime.now());
  }

  void _setMonth(AgendaMonthKey monthKey, Set<AgendaDayKey> collapsed) {
    final next = Map<AgendaMonthKey, Set<AgendaDayKey>>.from(
      state.collapsedByMonth,
    );
    if (collapsed.isEmpty) {
      next.remove(monthKey);
    } else {
      next[monthKey] = collapsed;
    }
    state = AgendaCollapseState(collapsedByMonth: next);
  }
}

final agendaCollapseProvider =
    NotifierProvider<AgendaCollapseNotifier, AgendaCollapseState>(
      AgendaCollapseNotifier.new,
    );
