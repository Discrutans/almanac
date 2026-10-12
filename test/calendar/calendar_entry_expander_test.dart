import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/events/calendar_entry_expander.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/data/savings/savings_goal_repository.dart';
import 'package:almanac/data/schedules/cyclic_work_schedule_repository.dart';
import 'package:almanac/finance/savings_goal_types.dart';

void main() {
  group('CalendarEntryExpander', () {
    const profileId = 'default';
    const schedule = CyclicWorkSchedule(
      id: 'sched-test',
      profileId: profileId,
      title: 'Weekdays',
      kind: CyclicScheduleKind.rrule,
      rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      startTime: '09:00',
      endTime: '10:00',
      colorValue: 0xFF009688,
    );

    test('tags generated schedule views with scheduleGenerated', () {
      final expanded = CalendarEntryExpander.expandProfile(
        storedMasters: const [],
        schedules: const [schedule],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 8),
      );

      expect(expanded, isNotEmpty);
      expect(
        expanded.every(
          (event) => event.entrySource == CalendarEntrySource.scheduleGenerated,
        ),
        isTrue,
      );
    });

    test(
      'hides generated shift when schedule override exists for that day',
      () {
        final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
          seedDemoData: false,
        );
        scheduleRepo.add(schedule);

        final repo = InMemoryEventRepository(
          scheduleRepository: scheduleRepo,
          seedDemoData: false,
        );
        repo.ensureProfile(profileId);

        final overrideDay = DateTime(2026, 6, 1, 9);
        repo.upsertScheduleOverride(
          profileId: profileId,
          override: AppEvent(
            id: AppEvent.scheduleOverrideId('sched-test', overrideDay),
            dateTimeRange: DateTimeRange(
              start: overrideDay,
              end: overrideDay.add(const Duration(hours: 1)),
            ),
            title: 'Custom shift',
            startTime: '09:00',
            endTime: '10:00',
            color: Colors.teal,
            seriesId: 'schedule-sched-test',
          ).taggedWith(CalendarEntrySource.scheduleOverride),
        );

        final expanded = repo.getEventsForRange(
          profileId: profileId,
          rangeStart: DateTime(2026, 6, 1),
          rangeEnd: DateTime(2026, 6, 8),
        );

        expect(
          expanded.any(
            (event) =>
                event.title == 'Custom shift' &&
                event.entrySource == CalendarEntrySource.scheduleOverride,
          ),
          isTrue,
        );
        expect(
          expanded.where(
            (event) =>
                event.entrySource == CalendarEntrySource.scheduleGenerated &&
                AppEvent.recurrenceDayKey(event.start) ==
                    AppEvent.recurrenceDayKey(overrideDay),
          ),
          isEmpty,
        );
      },
    );

    test('expandVisibleProfiles merges savings goals with explicit source', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final eventRepo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      eventRepo.ensureProfile(profileId);

      final savingsRepo = InMemorySavingsGoalRepository();
      savingsRepo.add(
        SavingsGoal(
          id: 'goal-1',
          profileId: profileId,
          title: 'Vacation',
          targetAmount: 100000,
          targetDate: DateTime(2026, 8, 15),
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      final merged = CalendarEntryExpander.expandVisibleProfiles(
        eventRepository: eventRepo,
        savingsGoalRepository: savingsRepo,
        profileIds: const {profileId},
        rangeStart: DateTime(2026, 8, 1),
        rangeEnd: DateTime(2026, 9, 1),
      );

      expect(merged.where((event) => event.title == 'Vacation'), hasLength(1));
      final goal = merged.firstWhere((event) => event.title == 'Vacation');
      expect(goal.entrySource, CalendarEntrySource.savingsGoalProjected);
    });
  });

  test('AppEvent resolves legacy override id without explicit tag', () {
    final event = AppEvent(
      id: AppEvent.scheduleOverrideId('sched-1', DateTime(2026, 6, 1)),
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
      ),
      title: 'Override',
      startTime: '09:00',
      endTime: '10:00',
      color: Colors.blue,
      seriesId: 'schedule-sched-1',
    );

    expect(event.entrySource, CalendarEntrySource.scheduleOverride);
    expect(event.capabilities.canRevertOverride, isTrue);
  });

  test('undated notes stay out of the calendar range and in the inbox list', () {
    const profileId = 'default';
    final repo = InMemoryEventRepository(seedDemoData: false);
    repo.ensureProfile(profileId);
    repo.addEvent(
      profileId: profileId,
      event: AppEvent(
        id: 'undated-note',
        dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 6, 2)),
        title: 'Inbox note',
        startTime: '',
        endTime: '',
        color: Colors.orange,
        kind: CalendarEntryKind.note,
        notes: 'buy milk',
        isUndated: true,
      ),
    );

    final visible = repo.getEventsForRange(
      profileId: profileId,
      rangeStart: DateTime(2026, 6, 1),
      rangeEnd: DateTime(2026, 6, 8),
    );
    expect(visible.any((event) => event.id == 'undated-note'), isFalse);
    expect(
      repo.getUndatedEvents(profileId: profileId).map((e) => e.id),
      contains('undated-note'),
    );
  });
}
