import '../data/holidays/russian_holidays.dart';
import '../data/profiles/context_profile.dart';
import 'calendar_event_index.dart';
import 'calendar_types.dart';
import '../finance/pay_types.dart';
import '../finance/work_pay_calculator.dart';

/// Сводка по событиям внутри календарного месяца.
class MonthStatistics {
  const MonthStatistics({
    required this.totalEvents,
    required this.daysWithEvents,
    required this.daysInMonth,
    required this.scheduleEvents,
    required this.personalEvents,
    required this.checklistTasksTotal,
    required this.checklistTasksDone,
    required this.busiestDay,
    required this.busiestDayCount,
    required this.weeklyCounts,
    required this.workPay,
    required this.holidayCount,
    required this.noteCount,
    required this.checklistCount,
    required this.bookingCount,
    required this.pendingBookingCount,
    required this.savingsGoalCount,
  });

  final int totalEvents;
  final int daysWithEvents;
  final int daysInMonth;
  final int scheduleEvents;
  final int personalEvents;
  final int checklistTasksTotal;
  final int checklistTasksDone;
  final DateTime? busiestDay;
  final int busiestDayCount;
  final List<int> weeklyCounts;
  final WorkPaySummary workPay;
  final int holidayCount;
  final int noteCount;
  final int checklistCount;
  final int bookingCount;
  final int pendingBookingCount;
  final int savingsGoalCount;

  double get occupancyRatio =>
      daysInMonth == 0 ? 0 : daysWithEvents / daysInMonth;

  double? get checklistProgress {
    if (checklistTasksTotal == 0) return null;
    return checklistTasksDone / checklistTasksTotal;
  }

  int get maxWeeklyCount =>
      weeklyCounts.isEmpty ? 0 : weeklyCounts.reduce((a, b) => a > b ? a : b);
}

MonthStatistics computeMonthStatistics({
  required DateTime focusedMonth,
  required List<AppEvent> events,
  Iterable<CyclicWorkSchedule> schedules = const [],
}) {
  final daysInMonth = DateTime(
    focusedMonth.year,
    focusedMonth.month + 1,
    0,
  ).day;
  final index = indexEventsByDay(events);

  var totalEvents = 0;
  var daysWithEvents = 0;
  var scheduleEvents = 0;
  var personalEvents = 0;
  var checklistTasksTotal = 0;
  var checklistTasksDone = 0;
  var noteCount = 0;
  var checklistCount = 0;
  var bookingCount = 0;
  var pendingBookingCount = 0;
  var savingsGoalCount = 0;
  DateTime? busiestDay;
  var busiestDayCount = 0;

  for (var day = 1; day <= daysInMonth; day++) {
    final date = DateTime(focusedMonth.year, focusedMonth.month, day);
    final dayEvents = eventsForDay(index, date);
    if (dayEvents.isEmpty) continue;

    daysWithEvents++;
    totalEvents += dayEvents.length;

    if (dayEvents.length > busiestDayCount) {
      busiestDayCount = dayEvents.length;
      busiestDay = date;
    }

    for (final event in dayEvents) {
      if (event.isFromWorkSchedule) {
        scheduleEvents++;
      } else {
        personalEvents++;
      }
      switch (event.kind) {
        case CalendarEntryKind.note:
          noteCount++;
        case CalendarEntryKind.checklist:
          checklistCount++;
        case CalendarEntryKind.savingsGoal:
          savingsGoalCount++;
        case CalendarEntryKind.event:
          break;
      }
      if (event.entrySource == CalendarEntrySource.booking) {
        bookingCount++;
      } else if (event.entrySource == CalendarEntrySource.bookingPending) {
        pendingBookingCount++;
      }
      checklistTasksTotal += event.checklistTotalCount;
      checklistTasksDone += event.checklistCompletedCount;
    }
  }

  final weeklyCounts = <int>[];
  for (var weekStart = 1; weekStart <= daysInMonth; weekStart += 7) {
    var weekTotal = 0;
    for (
      var day = weekStart;
      day < weekStart + 7 && day <= daysInMonth;
      day++
    ) {
      weekTotal += eventsForDay(
        index,
        DateTime(focusedMonth.year, focusedMonth.month, day),
      ).length;
    }
    weeklyCounts.add(weekTotal);
  }

  final workPay = computeWorkPaySummary(
    events: events,
    schedules: schedules,
    focusedMonth: focusedMonth,
  );

  return MonthStatistics(
    totalEvents: totalEvents,
    daysWithEvents: daysWithEvents,
    daysInMonth: daysInMonth,
    scheduleEvents: scheduleEvents,
    personalEvents: personalEvents,
    checklistTasksTotal: checklistTasksTotal,
    checklistTasksDone: checklistTasksDone,
    busiestDay: busiestDay,
    busiestDayCount: busiestDayCount,
    weeklyCounts: weeklyCounts,
    workPay: workPay,
    holidayCount: RussianHolidays.inMonth(focusedMonth).length,
    noteCount: noteCount,
    checklistCount: checklistCount,
    bookingCount: bookingCount,
    pendingBookingCount: pendingBookingCount,
    savingsGoalCount: savingsGoalCount,
  );
}
