import 'package:flutter/material.dart';
import '../calendar/calendar_types.dart';
import '../data/savings/savings_goal_repository.dart';
import 'savings_goal_types.dart';

/// Цвет цели накопления по умолчанию (зелёный).
const defaultSavingsGoalColorValue = 0xFF4CAF50;

/// Преобразует цели накопления в [AppEvent] для отображения в календаре.
abstract final class SavingsGoalCalendarProjection {
  static AppEvent toAppEvent(SavingsGoal goal) {
    return AppEvent(
      id: goal.id,
      dateTimeRange: AppEvent.dateOnlyRange(goal.targetDate),
      title: goal.title,
      startTime: goal.targetAmount.toString(),
      endTime: goal.savedAmount > 0 ? goal.savedAmount.toString() : '',
      color: Color(goal.effectiveColorValue),
      kind: CalendarEntryKind.savingsGoal,
      notes: goal.note,
      contextProfileId: goal.profileId,
    ).taggedWith(CalendarEntrySource.savingsGoalProjected);
  }

  static List<AppEvent> expandForProfiles({
    required Iterable<String> profileIds,
    required SavingsGoalRepository repository,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final projected = <AppEvent>[];

    for (final profileId in profileIds) {
      for (final goal in repository.getForProfile(profileId)) {
        if (_isDateInRange(goal.targetDate, rangeStart, rangeEnd)) {
          projected.add(toAppEvent(goal));
        }
      }
    }

    return projected;
  }

  static bool _isDateInRange(
    DateTime date,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(rangeStart) && day.isBefore(rangeEnd);
  }
}
