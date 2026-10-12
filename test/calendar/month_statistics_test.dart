import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/month_statistics.dart';
import 'package:almanac/finance/pay_types.dart';
import 'package:almanac/finance/work_pay_calculator.dart';
import 'package:almanac/data/holidays/russian_holidays.dart';
import 'package:almanac/data/profiles/context_profile.dart';

AppEvent _event({
  required String id,
  required DateTime day,
  required String start,
  required String end,
  bool schedule = false,
}) {
  final startParts = start.split(':');

  final endParts = end.split(':');

  final startDt = DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(startParts[0]),
    int.parse(startParts[1]),
  );

  final endDt = DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(endParts[0]),
    int.parse(endParts[1]),
  );

  return AppEvent(
    id: schedule ? 'schedule-demo-${day.millisecondsSinceEpoch}' : id,
    dateTimeRange: DateTimeRange(start: startDt, end: endDt),
    title: id,
    startTime: start,
    endTime: end,
    color: Colors.blue,
    seriesId: schedule ? 'schedule-demo' : null,
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  test('computeMonthStatistics counts events in focused month only', () {
    final month = DateTime(2026, 6, 1);
    final stats = computeMonthStatistics(
      focusedMonth: month,
      events: [
        _event(
          id: 'a',
          day: DateTime(2026, 6, 2),
          start: '09:00',
          end: '10:00',
        ),
        _event(
          id: 'b',
          day: DateTime(2026, 6, 2),
          start: '11:00',
          end: '12:00',
        ),
        _event(
          id: 'c',
          day: DateTime(2026, 6, 10),
          start: '09:00',
          end: '10:00',
        ),
        _event(
          id: 'outside',
          day: DateTime(2026, 7, 1),
          start: '09:00',
          end: '10:00',
        ),
      ],
    );

    expect(stats.totalEvents, 3);
    expect(stats.daysWithEvents, 2);
    expect(stats.daysInMonth, 30);
    expect(stats.busiestDay, DateTime(2026, 6, 2));
    expect(stats.busiestDayCount, 2);
    expect(stats.personalEvents, 3);
    expect(stats.weeklyCounts.length, 5);
    expect(stats.holidayCount, greaterThan(0));
  });

  test('computeMonthStatistics tracks checklist progress', () {
    final stats = computeMonthStatistics(
      focusedMonth: DateTime(2026, 6, 1),
      events: [
        AppEvent(
          id: 'with-checklist',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 5, 9),
            end: DateTime(2026, 6, 5, 10),
          ),
          title: 'Task day',
          startTime: '09:00',
          endTime: '10:00',
          color: Colors.green,
          checklist: const [
            ChecklistItem(id: '1', title: 'One', completed: true),
            ChecklistItem(id: '2', title: 'Two'),
          ],
          interaction: EventInteraction.allowNone(),
        ),
      ],
    );

    expect(stats.checklistTasksTotal, 2);
    expect(stats.checklistTasksDone, 1);
    expect(stats.checklistProgress, 0.5);
  });

  test('computeWorkPaySummary links shifts to numeric schedule ids', () {
    const scheduleId = 'sched-1734567890123456';
    const schedule = CyclicWorkSchedule(
      id: scheduleId,
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '10:00',
      colorValue: 0xFF0000FF,
      hourlyRate: 10,
      standardHoursPerShift: 8,
    );

    final summary = computeWorkPaySummary(
      events: [
        AppEvent(
          id: 'schedule-$scheduleId-${DateTime(2026, 6, 3).millisecondsSinceEpoch}',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 3, 8),
            end: DateTime(2026, 6, 3, 10),
          ),
          title: 'Смена',
          startTime: '08:00',
          endTime: '10:00',
          color: Colors.blue,
          seriesId: 'schedule-$scheduleId',
          contextProfileId: 'default',
          interaction: EventInteraction.allowNone(),
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.shiftCount, 1);
    expect(summary.regularMinutes, 2 * 60);
    expect(summary.regularPay, 20);
    expect(summary.totalPay, 20);
  });

  test('computeWorkPaySummary counts shifts and hourly pay', () {
    const schedule = CyclicWorkSchedule(
      id: 'demo',
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '17:00',
      colorValue: 0xFF0000FF,
      hourlyRate: 500,
      standardHoursPerShift: 8,
      overtimeMultiplier: 1.5,
    );

    final summary = computeWorkPaySummary(
      events: [
        _event(
          id: 'shift',
          day: DateTime(2026, 6, 3),
          start: '08:00',
          end: '20:00',
          schedule: true,
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.shiftCount, 1);
    expect(summary.totalWorkMinutes, 12 * 60);
    expect(summary.overtimeMinutes, 4 * 60);
    expect(summary.overtimePay, greaterThan(0));
    expect(summary.totalPay, greaterThan(4000));
  });

  test('computeWorkPaySummary excludes skipped shifts from pay', () {
    const schedule = CyclicWorkSchedule(
      id: 'demo',
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '17:00',
      colorValue: 0xFF0000FF,
      dailyRate: 3000,
      hourlyRate: 500,
      standardHoursPerShift: 8,
      overtimeMultiplier: 1.5,
      payMode: PayRateMode.daily,
    );

    final summary = computeWorkPaySummary(
      events: [
        _event(
          id: 'worked',
          day: DateTime(2026, 6, 3),
          start: '08:00',
          end: '16:00',
          schedule: true,
        ),
        AppEvent(
          id: 'schedule-override-demo-${DateTime(2026, 6, 4).millisecondsSinceEpoch}',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 4, 8),
            end: DateTime(2026, 6, 4, 17),
          ),
          title: 'Смена',
          startTime: '08:00',
          endTime: '17:00',
          color: Colors.blue,
          seriesId: 'schedule-demo',
          shiftSkipped: true,
          interaction: EventInteraction.allowNone(),
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.shiftCount, 1);
    expect(summary.skippedShiftCount, 1);
    expect(summary.regularPay, 3000);
    expect(summary.totalPay, 3000);
  });

  test('computeWorkPaySummary subtracts unpaid minutes', () {
    const schedule = CyclicWorkSchedule(
      id: 'demo',
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '17:00',
      colorValue: 0xFF0000FF,
      hourlyRate: 600,
      standardHoursPerShift: 8,
      payMode: PayRateMode.hourly,
    );

    final summary = computeWorkPaySummary(
      events: [
        AppEvent(
          id: 'schedule-demo-${DateTime(2026, 6, 5).millisecondsSinceEpoch}',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 5, 8),
            end: DateTime(2026, 6, 5, 17),
          ),
          title: 'Смена',
          startTime: '08:00',
          endTime: '17:00',
          color: Colors.blue,
          seriesId: 'schedule-demo',
          unpaidMinutes: 120,
          interaction: EventInteraction.allowNone(),
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.regularMinutes, 7 * 60);
    expect(summary.regularPay, 7 * 600);
  });

  test('computeWorkPaySummary counts work minutes for monthly pay mode', () {
    const schedule = CyclicWorkSchedule(
      id: 'monthly',
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '17:00',
      colorValue: 0xFF0000FF,
      payMode: PayRateMode.monthly,
      monthlyRate: 50000,
      standardHoursPerShift: 8,
    );

    final summary = computeWorkPaySummary(
      events: [
        AppEvent(
          id: 'schedule-monthly-${DateTime(2026, 6, 3).millisecondsSinceEpoch}',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 3, 8),
            end: DateTime(2026, 6, 3, 17),
          ),
          title: 'Смена',
          startTime: '08:00',
          endTime: '17:00',
          color: Colors.blue,
          seriesId: 'schedule-monthly',
          interaction: EventInteraction.allowNone(),
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.shiftCount, 1);
    expect(summary.totalWorkMinutes, 9 * 60);
    expect(summary.regularMinutes, 8 * 60);
    expect(summary.monthlyPay, greaterThan(0));
    expect(summary.totalPay, greaterThan(0));
  });

  test('computeWorkPaySummary adds bonus and withholds VAT from gross', () {
    const schedule = CyclicWorkSchedule(
      id: 'bonus-vat',
      profileId: 'default',
      title: 'Смена',
      startTime: '08:00',
      endTime: '10:00',
      colorValue: 0xFF0000FF,
      hourlyRate: 100,
      standardHoursPerShift: 8,
      bonusAmount: 1000,
      bonusPercent: 10,
      vatPercent: 20,
    );

    final summary = computeWorkPaySummary(
      events: [
        AppEvent(
          id: 'schedule-bonus-vat-${DateTime(2026, 6, 3).millisecondsSinceEpoch}',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 3, 8),
            end: DateTime(2026, 6, 3, 10),
          ),
          title: 'Смена',
          startTime: '08:00',
          endTime: '10:00',
          color: Colors.blue,
          seriesId: 'schedule-bonus-vat',
          contextProfileId: 'default',
          interaction: EventInteraction.allowNone(),
        ),
      ],
      schedules: [schedule],
      focusedMonth: DateTime(2026, 6, 1),
    );

    expect(summary.regularPay, 200);
    expect(summary.bonusPay, 1020);
    expect(summary.grossPay, 1220);
    expect(summary.vatAmount, 244);
    expect(summary.totalPay, 976);
  });

  test('RussianHolidays returns New Year', () {
    final holiday = RussianHolidays.onDate(DateTime(2026, 1, 1));
    expect(holiday, isNotNull);
    expect(holiday!.name, contains('Новый год'));
  });

  test('eventWorkDurationMinutes handles overnight shift', () {
    final event = AppEvent(
      id: 'night',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 1, 22),
        end: DateTime(2026, 6, 2, 6),
      ),
      title: 'Night',
      startTime: '22:00',
      endTime: '06:00',
      color: Colors.blue,
      interaction: EventInteraction.allowNone(),
    );

    expect(eventWorkDurationMinutes(event), 8 * 60);
  });
}
