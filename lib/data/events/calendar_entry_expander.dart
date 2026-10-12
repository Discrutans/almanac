import '../../calendar/calendar_types.dart';
import '../../finance/savings_goal_calendar_projection.dart';
import '../schedules/cyclic_schedule_generator.dart';
import '../profiles/context_profile.dart';
import '../savings/savings_goal_repository.dart';
import 'event_repository.dart';
import 'recurrence_engine.dart';

/// Единый пайплайн развёртывания записей календаря для диапазона дат.
final class CalendarEntryExpander {
  CalendarEntryExpander._();

  static List<AppEvent> expandProfile({
    required List<AppEvent> storedMasters,
    required List<CyclicWorkSchedule> schedules,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final datedMasters = [
      for (final event in storedMasters)
        if (!event.isUndated) event,
    ];
    final expandedStored = RecurrenceEngine.expandAll(
      datedMasters,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final taggedStored = expandedStored.map(_tagStoredEvent).toList();
    final overrideKeys = _scheduleOverrideKeys(storedMasters);

    final generatedSchedules = CyclicScheduleEventGenerator.expandForRange(
      schedules: schedules,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    ).map((event) => event.taggedWith(CalendarEntrySource.scheduleGenerated));

    final filteredSchedules = generatedSchedules.where((event) {
      final scheduleId = event.workScheduleId;
      if (scheduleId == null) return true;
      return !overrideKeys.contains(
        AppEvent.scheduleOverrideKey(scheduleId, event.start),
      );
    });

    return [...taggedStored, ...filteredSchedules]
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  static List<AppEvent> expandVisibleProfiles({
    required EventRepository eventRepository,
    required SavingsGoalRepository savingsGoalRepository,
    required Iterable<String> profileIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final merged = <AppEvent>[];

    for (final profileId in profileIds) {
      final events = eventRepository.getEventsForRange(
        profileId: profileId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      merged.addAll(
        events.map((event) => event.copyWith(contextProfileId: profileId)),
      );
    }

    merged.addAll(
      SavingsGoalCalendarProjection.expandForProfiles(
        profileIds: profileIds,
        repository: savingsGoalRepository,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );

    merged.sort((a, b) => a.start.compareTo(b.start));
    return merged;
  }

  static Set<String> _scheduleOverrideKeys(List<AppEvent> masters) {
    final keys = <String>{};
    for (final event in masters) {
      if (event.entrySource != CalendarEntrySource.scheduleOverride) continue;
      final scheduleId = event.workScheduleId;
      if (scheduleId == null) continue;
      keys.add(AppEvent.scheduleOverrideKey(scheduleId, event.start));
      final occurrenceDate = AppEvent.scheduleOverrideDateFromId(event.id);
      if (occurrenceDate != null) {
        keys.add(AppEvent.scheduleOverrideKey(scheduleId, occurrenceDate));
      }
    }
    return keys;
  }

  static AppEvent _tagStoredEvent(AppEvent event) {
    if (event.isRecurrenceOccurrence) {
      return event;
    }

    switch (event.entrySource) {
      case CalendarEntrySource.scheduleOverride:
        return event.taggedWith(CalendarEntrySource.scheduleOverride);
      case CalendarEntrySource.scheduleGenerated:
        return event.taggedWith(CalendarEntrySource.scheduleGenerated);
      case CalendarEntrySource.savingsGoalProjected:
        return event.taggedWith(CalendarEntrySource.savingsGoalProjected);
      case CalendarEntrySource.personal:
      case CalendarEntrySource.booking:
      case CalendarEntrySource.bookingPending:
      case CalendarEntrySource.bookingSlot:
      case CalendarEntrySource.bookingOffer:
      case CalendarEntrySource.guestCalendar:
        return event;
    }
  }
}
