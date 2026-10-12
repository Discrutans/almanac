import '../data/profiles/context_profile.dart';

/// Способ расчёта оплаты смены.
enum PayRateMode { hourly, daily, monthly }

/// Заработок по одному рабочему расписанию за месяц.
class SchedulePayBreakdown {
  const SchedulePayBreakdown({
    required this.shiftCount,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.regularPay,
    required this.overtimePay,
    required this.monthlyPay,
    required this.bonusPay,
    required this.vatAmount,
  });

  final int shiftCount;
  final int regularMinutes;
  final int overtimeMinutes;
  final double regularPay;
  final double overtimePay;
  final double monthlyPay;
  final double bonusPay;
  final double vatAmount;
  int get totalWorkMinutes => regularMinutes + overtimeMinutes;
  double get subtotalPay => regularPay + overtimePay + monthlyPay + bonusPay;
  double get grossPay => subtotalPay;
  double get totalPay => grossPay - vatAmount;
  static const zero = SchedulePayBreakdown(
    shiftCount: 0,
    regularMinutes: 0,
    overtimeMinutes: 0,
    regularPay: 0,
    overtimePay: 0,
    monthlyPay: 0,
    bonusPay: 0,
    vatAmount: 0,
  );
}

/// Разбивка рабочего времени и заработка за период.
class WorkPaySummary {
  const WorkPaySummary({
    required this.shiftCount,
    required this.skippedShiftCount,
    required this.totalWorkMinutes,
    required this.regularMinutes,
    required this.overtimeMinutes,
    required this.regularPay,
    required this.overtimePay,
    required this.monthlyPay,
    required this.bonusPay,
    required this.vatAmount,
    required this.totalPay,
    required this.byScheduleKey,
  });

  final int shiftCount;
  final int skippedShiftCount;
  final int totalWorkMinutes;
  final int regularMinutes;
  final int overtimeMinutes;
  final double regularPay;
  final double overtimePay;
  final double monthlyPay;
  final double bonusPay;
  final double vatAmount;
  final double totalPay;
  final Map<String, SchedulePayBreakdown> byScheduleKey;
  double get totalWorkHours => totalWorkMinutes / 60;
  double get overtimeHours => overtimeMinutes / 60;
  double get subtotalPay => regularPay + overtimePay + monthlyPay + bonusPay;
  double get basePay => regularPay + overtimePay + monthlyPay;
  double get grossPay => subtotalPay;
  bool get hasPayConfigured =>
      regularPay > 0 ||
      overtimePay > 0 ||
      monthlyPay > 0 ||
      bonusPay > 0 ||
      vatAmount > 0;
  SchedulePayBreakdown breakdownFor(CyclicWorkSchedule schedule) {
    return byScheduleKey[schedulePayKey(schedule)] ?? SchedulePayBreakdown.zero;
  }

  static const empty = WorkPaySummary(
    shiftCount: 0,
    skippedShiftCount: 0,
    totalWorkMinutes: 0,
    regularMinutes: 0,
    overtimeMinutes: 0,
    regularPay: 0,
    overtimePay: 0,
    monthlyPay: 0,
    bonusPay: 0,
    vatAmount: 0,
    totalPay: 0,
    byScheduleKey: {},
  );
}

String schedulePayKey(CyclicWorkSchedule schedule) =>
    '${schedule.profileId}::${schedule.id}';

/// Настройки напоминаний.
abstract final class ReminderPresets {
  static const maxMinutesBefore = 525600; // 365 days
}
