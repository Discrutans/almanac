import '../calendar/calendar_types.dart';
import '../calendar/event_time_utils.dart';
import '../data/profiles/context_profile.dart';
import 'pay_types.dart';

WorkPaySummary computeWorkPaySummary({
  required List<AppEvent> events,
  required Iterable<CyclicWorkSchedule> schedules,
  required DateTime focusedMonth,
}) {
  final schedulesList = schedules.toList();
  var shiftCount = 0;
  var skippedShiftCount = 0;
  var totalWorkMinutes = 0;
  var regularMinutes = 0;
  var overtimeMinutes = 0;
  var regularPay = 0.0;
  var overtimePay = 0.0;
  var monthlyPayAcc = 0.0;
  var bonusPayAcc = 0.0;
  var vatPayAcc = 0.0;
  final byScheduleKey = <String, SchedulePayBreakdown>{};
  final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);

  final monthEnd = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);

  final shiftsBySchedule = <String, int>{};

  void addSlice(
    CyclicWorkSchedule schedule, {
    int shiftDelta = 0,
    int regularMinutesDelta = 0,
    int overtimeMinutesDelta = 0,
    double regularPayDelta = 0,
    double overtimePayDelta = 0,
    double monthlyPayDelta = 0,
    double bonusPayDelta = 0,
    double vatPayDelta = 0,
  }) {
    final key = schedulePayKey(schedule);
    final current = byScheduleKey[key] ?? SchedulePayBreakdown.zero;
    byScheduleKey[key] = SchedulePayBreakdown(
      shiftCount: current.shiftCount + shiftDelta,
      regularMinutes: current.regularMinutes + regularMinutesDelta,
      overtimeMinutes: current.overtimeMinutes + overtimeMinutesDelta,
      regularPay: current.regularPay + regularPayDelta,
      overtimePay: current.overtimePay + overtimePayDelta,
      monthlyPay: current.monthlyPay + monthlyPayDelta,
      bonusPay: current.bonusPay + bonusPayDelta,
      vatAmount: current.vatAmount + vatPayDelta,
    );
  }

  for (final event in events) {
    if (!event.isFromWorkSchedule) continue;
    if (!_isInMonth(event.start, monthStart, monthEnd)) continue;
    if (event.shiftSkipped) {
      skippedShiftCount++;
      continue;
    }
    shiftCount++;
    final schedule = resolveScheduleForEvent(event, schedulesList);
    if (schedule != null) {
      addSlice(schedule, shiftDelta: 1);
      final key = schedulePayKey(schedule);
      shiftsBySchedule[key] = (shiftsBySchedule[key] ?? 0) + 1;
    }
    final split = schedule == null
        ? (regularMinutes: eventWorkDurationMinutes(event), overtimeMinutes: 0)
        : splitWorkMinutes(
            event: event,
            standardHoursPerShift: schedule.standardHoursPerShift,
            breakMinutes: schedule.breakMinutes,
          );
    totalWorkMinutes += split.regularMinutes + split.overtimeMinutes;
    regularMinutes += split.regularMinutes;
    overtimeMinutes += split.overtimeMinutes;
    if (schedule != null) {
      addSlice(
        schedule,
        regularMinutesDelta: split.regularMinutes,
        overtimeMinutesDelta: split.overtimeMinutes,
      );
    }
    if (schedule == null) continue;
    if (schedule.payMode == PayRateMode.monthly) {
      final otPay = _overtimeEarnings(schedule: schedule, split: split);
      overtimePay += otPay;
      addSlice(schedule, overtimePayDelta: otPay);
      continue;
    }
    final earnings = _eventEarnings(
      event: event,
      schedule: schedule,
      split: split,
    );
    regularPay += earnings.regular;
    overtimePay += earnings.overtime;
    addSlice(
      schedule,
      regularPayDelta: earnings.regular,
      overtimePayDelta: earnings.overtime,
    );
  }
  for (final schedule in schedulesList) {
    if (schedule.payMode != PayRateMode.monthly) continue;
    final key = schedulePayKey(schedule);
    final worked = shiftsBySchedule[key] ?? 0;
    if (worked <= 0) continue;
    final rate = schedule.monthlyRate ?? 0;
    if (rate <= 0) continue;
    final expected = _expectedShiftsInMonth(schedule, monthStart, monthEnd);
    final monthly = expected <= 0 ? rate : rate * (worked / expected);
    monthlyPayAcc += monthly;
    addSlice(schedule, monthlyPayDelta: monthly);
  }
  for (final schedule in schedulesList) {
    final key = schedulePayKey(schedule);
    final worked = shiftsBySchedule[key] ?? 0;
    if (worked <= 0) continue;
    final slice = byScheduleKey[key] ?? SchedulePayBreakdown.zero;
    final bonusPercent = schedule.bonusPercent ?? 0;
    if (bonusPercent > 0) {
      final percentBase = switch (schedule.payMode) {
        PayRateMode.monthly => slice.monthlyPay,
        _ => slice.regularPay + slice.overtimePay + slice.monthlyPay,
      };
      if (percentBase > 0) {
        final bonusFromPercent = percentBase * bonusPercent / 100;
        bonusPayAcc += bonusFromPercent;
        addSlice(schedule, bonusPayDelta: bonusFromPercent);
      }
    }
    final fixedBonus = schedule.bonusAmount ?? 0;
    if (fixedBonus > 0) {
      bonusPayAcc += fixedBonus;
      addSlice(schedule, bonusPayDelta: fixedBonus);
    }
    final sliceAfterBonus = byScheduleKey[key] ?? SchedulePayBreakdown.zero;
    final gross =
        sliceAfterBonus.regularPay +
        sliceAfterBonus.overtimePay +
        sliceAfterBonus.monthlyPay +
        sliceAfterBonus.bonusPay;
    final vatPercent = schedule.vatPercent ?? 0;
    if (vatPercent > 0 && gross > 0) {
      final vat = gross * vatPercent / 100;
      vatPayAcc += vat;
      addSlice(schedule, vatPayDelta: vat);
    }
  }
  final grossPay = regularPay + overtimePay + monthlyPayAcc + bonusPayAcc;
  final totalPay = grossPay - vatPayAcc;
  return WorkPaySummary(
    shiftCount: shiftCount,
    skippedShiftCount: skippedShiftCount,
    totalWorkMinutes: totalWorkMinutes,
    regularMinutes: regularMinutes,
    overtimeMinutes: overtimeMinutes,
    regularPay: regularPay,
    overtimePay: overtimePay,
    monthlyPay: monthlyPayAcc,
    bonusPay: bonusPayAcc,
    vatAmount: vatPayAcc,
    totalPay: totalPay,
    byScheduleKey: byScheduleKey,
  );
}

CyclicWorkSchedule? resolveScheduleForEvent(
  AppEvent event,
  Iterable<CyclicWorkSchedule> schedules,
) {
  final scheduleId = event.workScheduleId;
  if (scheduleId == null) return null;
  final profileId = event.contextProfileId;
  CyclicWorkSchedule? fallback;
  for (final schedule in schedules) {
    if (schedule.id != scheduleId) continue;
    if (profileId != null && schedule.profileId == profileId) {
      return schedule;
    }
    fallback ??= schedule;
  }
  return fallback;
}

bool _isInMonth(DateTime date, DateTime start, DateTime end) {
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(start) && !day.isAfter(end);
}

double _overtimeEarnings({
  required CyclicWorkSchedule schedule,
  required ({int regularMinutes, int overtimeMinutes}) split,
}) {
  if (split.overtimeMinutes <= 0) return 0;
  final hourly = schedule.hourlyRate ?? 0;
  if (hourly <= 0) return 0;
  return (split.overtimeMinutes / 60) * hourly * schedule.overtimeMultiplier;
}

({double regular, double overtime}) _eventEarnings({
  required AppEvent event,
  required CyclicWorkSchedule schedule,
  required ({int regularMinutes, int overtimeMinutes}) split,
}) {
  final otMultiplier = schedule.overtimeMultiplier;
  final hourly = schedule.hourlyRate ?? 0;
  switch (schedule.payMode) {
    case PayRateMode.hourly:
      final regular = (split.regularMinutes / 60) * hourly;
      final overtime = (split.overtimeMinutes / 60) * hourly * otMultiplier;
      return (regular: regular, overtime: overtime);
    case PayRateMode.daily:
      final daily = schedule.dailyRate ?? 0;
      final overtime = hourly > 0
          ? (split.overtimeMinutes / 60) * hourly * otMultiplier
          : 0.0;
      return (regular: daily, overtime: overtime);
    case PayRateMode.monthly:
      return (regular: 0, overtime: 0);
  }
}

int _expectedShiftsInMonth(
  CyclicWorkSchedule schedule,
  DateTime monthStart,
  DateTime monthEnd,
) {
  if (schedule.isShiftCycle &&
      schedule.cycleStartDate != null &&
      schedule.workDays > 0) {
    var count = 0;
    for (
      var day = monthStart;
      !day.isAfter(monthEnd);
      day = day.add(const Duration(days: 1))
    ) {
      if (_isShiftWorkDay(schedule, day)) count++;
    }
    return count;
  }
  return monthEnd.day;
}

bool _isShiftWorkDay(CyclicWorkSchedule schedule, DateTime date) {
  final start = schedule.cycleStartDate;
  if (start == null || schedule.workDays <= 0) return false;
  final cycleLength = schedule.workDays + schedule.restDays;
  if (cycleLength <= 0) return false;
  final day = DateTime(date.year, date.month, date.day);

  final anchor = DateTime(start.year, start.month, start.day);

  final diff = day.difference(anchor).inDays;
  if (diff < 0) return false;
  final pos = diff % cycleLength;
  return pos < schedule.workDays;
}

Map<String, CyclicWorkSchedule> schedulesById(
  Iterable<CyclicWorkSchedule> schedules,
) {
  return {for (final s in schedules) s.id: s};
}

List<CyclicWorkSchedule> activePaidSchedules({
  required Iterable<CyclicWorkSchedule> schedules,
  required WorkPaySummary summary,
}) {
  if (summary.shiftCount == 0 && summary.skippedShiftCount == 0) {
    return const [];
  }
  return schedules.where((schedule) {
    final slice = summary.breakdownFor(schedule);
    if (slice.shiftCount <= 0) return false;
    return switch (schedule.payMode) {
      PayRateMode.hourly => (schedule.hourlyRate ?? 0) > 0,
      PayRateMode.daily => (schedule.dailyRate ?? 0) > 0,
      PayRateMode.monthly => (schedule.monthlyRate ?? 0) > 0,
    };
  }).toList();
}

bool hasShiftsWithoutPayRates({
  required Iterable<CyclicWorkSchedule> schedules,
  required WorkPaySummary summary,
}) {
  if (summary.shiftCount == 0) return false;
  final withShifts = schedules.where(
    (schedule) => summary.breakdownFor(schedule).shiftCount > 0,
  );
  if (withShifts.isEmpty) return true;
  return withShifts.every((schedule) {
    return switch (schedule.payMode) {
      PayRateMode.hourly => (schedule.hourlyRate ?? 0) <= 0,
      PayRateMode.daily => (schedule.dailyRate ?? 0) <= 0,
      PayRateMode.monthly => (schedule.monthlyRate ?? 0) <= 0,
    };
  });
}
