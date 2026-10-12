import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/finance/pay_types.dart';
import 'package:almanac/finance/work_pay_calculator.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _shift({
  required String scheduleId,
  required DateTime day,
  int overtimeMinutes = 0,
}) {
  final start = DateTime(day.year, day.month, day.day, 9);
  return AppEvent(
    id: 'schedule-$scheduleId-${start.millisecondsSinceEpoch}',
    seriesId: 'schedule-$scheduleId',
    dateTimeRange: DateTimeRange(
      start: start,
      end: start.add(const Duration(hours: 8)),
    ),
    title: 'Shift',
    startTime: '09:00',
    endTime: '17:00',
    color: Colors.blue,
    overtimeMinutes: overtimeMinutes,
    interaction: EventInteraction.allowNone(),
  );
}

CyclicWorkSchedule _monthlySchedule({
  double? bonusPercent,
  double? bonusAmount,
  double? vatPercent,
  double? hourlyRate,
}) {
  return CyclicWorkSchedule(
    id: 'sched-1',
    profileId: 'profile-1',
    title: 'Office',
    startTime: '09:00',
    endTime: '17:00',
    colorValue: Colors.blue.toARGB32(),
    payMode: PayRateMode.monthly,
    monthlyRate: 50000,
    hourlyRate: hourlyRate,
    bonusPercent: bonusPercent,
    bonusAmount: bonusAmount,
    vatPercent: vatPercent,
  );
}

void main() {
  final focusedMonth = DateTime(2026, 7, 1);

  test('monthly pay example: oklad + fixed bonus + percent bonus - vat', () {
    final schedule = _monthlySchedule(
      bonusPercent: 50,
      bonusAmount: 10000,
      vatPercent: 13,
    );

    final events = [
      for (var day = 1; day <= 31; day++)
        _shift(scheduleId: schedule.id, day: DateTime(2026, 7, day)),
    ];

    final summary = computeWorkPaySummary(
      events: events,
      schedules: [schedule],
      focusedMonth: focusedMonth,
    );

    expect(summary.monthlyPay, 50000);
    expect(summary.bonusPay, 35000);
    expect(summary.grossPay, 85000);
    expect(summary.vatAmount, closeTo(11050, 0.01));
    expect(summary.totalPay, closeTo(73950, 0.01));
  });

  test('monthly bonus percent uses oklad only, not overtime pay', () {
    final schedule = _monthlySchedule(bonusPercent: 50, hourlyRate: 1000);

    final events = [
      _shift(
        scheduleId: schedule.id,
        day: DateTime(2026, 7, 1),
        overtimeMinutes: 120,
      ),
    ];

    final summary = computeWorkPaySummary(
      events: events,
      schedules: [schedule],
      focusedMonth: focusedMonth,
    );

    expect(summary.overtimePay, greaterThan(0));
    expect(summary.bonusPay, closeTo(summary.monthlyPay * 0.5, 0.01));
    expect(
      summary.bonusPay,
      isNot(summary.monthlyPay * 0.5 + summary.overtimePay * 0.5),
    );
  });
}
