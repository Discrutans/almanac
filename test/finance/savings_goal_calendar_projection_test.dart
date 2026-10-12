import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/savings/savings_goal_repository.dart';
import 'package:almanac/finance/savings_goal_calendar_projection.dart';
import 'package:almanac/finance/savings_goal_types.dart';

void main() {
  test('projects savings goal into visible calendar range', () {
    final repo = InMemorySavingsGoalRepository();
    final goal = SavingsGoal(
      id: 'goal-1',
      profileId: 'default',
      title: 'Vacation',
      targetAmount: 100000,
      targetDate: DateTime(2026, 8, 15),
      createdAt: DateTime(2026, 1, 1),
    );
    repo.add(goal);

    final projected = SavingsGoalCalendarProjection.expandForProfiles(
      profileIds: const {'default'},
      repository: repo,
      rangeStart: DateTime(2026, 8, 1),
      rangeEnd: DateTime(2026, 9, 1),
    );

    expect(projected, hasLength(1));
    expect(projected.first.title, 'Vacation');
    expect(projected.first.isSavingsGoal, isTrue);
    expect(
      projected.first.entrySource,
      CalendarEntrySource.savingsGoalProjected,
    );
    expect(projected.first.savingsTargetAmount, 100000);
    expect(projected.first.canDragInWeekView, isTrue);
  });

  test('skips goals outside visible range', () {
    final repo = InMemorySavingsGoalRepository();
    repo.add(
      SavingsGoal(
        id: 'goal-2',
        profileId: 'default',
        title: 'Later',
        targetAmount: 50000,
        targetDate: DateTime(2027, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final projected = SavingsGoalCalendarProjection.expandForProfiles(
      profileIds: const {'default'},
      repository: repo,
      rangeStart: DateTime(2026, 8, 1),
      rangeEnd: DateTime(2026, 9, 1),
    );

    expect(projected, isEmpty);
  });
}
