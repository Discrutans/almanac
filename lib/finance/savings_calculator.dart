import 'dart:math' as math;
import '../calendar/calendar_event_index.dart';
import 'savings_goal_types.dart';

DateTime _dateOnly(DateTime value) => calendarDayKey(value);

int savingsDaysRemaining({required DateTime targetDate, DateTime? asOf}) {
  final today = _dateOnly(asOf ?? DateTime.now());

  final deadline = _dateOnly(targetDate);
  return deadline.difference(today).inDays;
}

int savingsMonthsRemaining({required DateTime targetDate, DateTime? asOf}) {
  final days = savingsDaysRemaining(targetDate: targetDate, asOf: asOf);
  if (days <= 0) return 0;
  return math.max(1, (days / 30.4375).ceil());
}

double computeMonthlySavingsNeeded({
  required double targetAmount,
  required DateTime targetDate,
  DateTime? asOf,
}) {
  if (targetAmount <= 0) return 0;

  final days = savingsDaysRemaining(targetDate: targetDate, asOf: asOf);
  if (days <= 0) return targetAmount;

  final months = savingsMonthsRemaining(targetDate: targetDate, asOf: asOf);
  return targetAmount / months;
}

SavingsPlanSummary computeSavingsPlan({
  required SavingsGoal goal,
  DateTime? asOf,
  double? monthlyNetIncome,
}) {
  final days = savingsDaysRemaining(targetDate: goal.targetDate, asOf: asOf);

  final months = savingsMonthsRemaining(
    targetDate: goal.targetDate,
    asOf: asOf,
  );

  final monthlySavings = computeMonthlySavingsNeeded(
    targetAmount: goal.targetAmount,
    targetDate: goal.targetDate,
    asOf: asOf,
  );

  final living = goal.monthlyLivingExpenses;
  final budget = monthlySavings + living;
  final isOverdue = days < 0;

  double? surplus;
  if (monthlyNetIncome != null && monthlyNetIncome > 0) {
    surplus = monthlyNetIncome - budget;
  }

  return SavingsPlanSummary(
    goal: goal,
    daysRemaining: days,
    monthsRemaining: months,
    monthlySavingsNeeded: monthlySavings,
    monthlyLivingExpenses: living,
    totalMonthlyBudget: budget,
    isOverdue: isOverdue,
    surplusAfterBudget: surplus,
  );
}

List<SavingsPlanSummary> computeSavingsPlans({
  required Iterable<SavingsGoal> goals,
  DateTime? asOf,
  double? monthlyNetIncome,
}) {
  return goals
      .map(
        (goal) => computeSavingsPlan(
          goal: goal,
          asOf: asOf,
          monthlyNetIncome: monthlyNetIncome,
        ),
      )
      .toList(growable: false);
}
