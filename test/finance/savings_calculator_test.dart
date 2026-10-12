import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/finance/savings_calculator.dart';
import 'package:almanac/finance/savings_goal_types.dart';

void main() {
  test('computeMonthlySavingsNeeded splits target by remaining months', () {
    final goal = SavingsGoal(
      id: 'g1',
      profileId: 'default',
      title: 'Vacation',
      targetAmount: 120000,
      targetDate: DateTime(2026, 12, 31),
      monthlyLivingExpenses: 30000,
      createdAt: DateTime(2026, 6, 1),
    );

    final plan = computeSavingsPlan(
      goal: goal,
      asOf: DateTime(2026, 6, 15),
      monthlyNetIncome: 85000,
    );

    expect(plan.monthlySavingsNeeded, greaterThan(0));
    expect(plan.totalMonthlyBudget, plan.monthlySavingsNeeded + 30000);
    expect(plan.surplusAfterBudget, isNotNull);
    expect(plan.daysRemaining, greaterThan(0));
  });

  test('overdue goal requires full amount immediately', () {
    final monthly = computeMonthlySavingsNeeded(
      targetAmount: 50000,
      targetDate: DateTime(2026, 1, 1),
      asOf: DateTime(2026, 6, 1),
    );

    expect(monthly, 50000);
  });
}
