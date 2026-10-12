import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/shift_quick_actions.dart';
import 'package:almanac/calendar/test_calendar_fill.dart';
import 'package:almanac/data/events/event_overlap.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/data/schedules/cyclic_schedule_generator.dart';
import 'package:almanac/data/schedules/cyclic_work_schedule_repository.dart';
import 'package:almanac/finance/savings_goal_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profileId = 'default';
  final now = DateTime(2026, 9, 11);

  late List<AppEvent> events;
  late List<CyclicWorkSchedule> schedules;
  late List<SavingsGoal> goals;

  setUp(() {
    events = TestCalendarFill.personalEvents(profileId, year: 2026, now: now);
    schedules = TestCalendarFill.schedules(profileId, year: 2026);
    goals = TestCalendarFill.savingsGoals(profileId, year: 2026, now: now);
  });

  test('seed contains every entry kind and supporting features', () {
    expect(schedules, hasLength(2));
    expect(goals, hasLength(4));

    final kinds = events.map((event) => event.kind).toSet();
    expect(kinds, contains(CalendarEntryKind.event));
    expect(kinds, contains(CalendarEntryKind.note));
    expect(kinds, contains(CalendarEntryKind.checklist));

    expect(events.any((event) => event.hasRecurrence), isTrue);
    expect(
      events.any(
        (event) => event.rrule != null && event.rrule!.contains('FREQ=DAILY'),
      ),
      isTrue,
    );
    expect(
      events.any(
        (event) => event.rrule != null && event.rrule!.contains('FREQ=WEEKLY'),
      ),
      isTrue,
    );
    expect(
      events.any((event) => event.recurrenceExclusions.isNotEmpty),
      isTrue,
    );
    expect(events.any((event) => event.reminderMinutesBefore != null), isTrue);
    expect(events.any((event) => event.attachments.isNotEmpty), isTrue);
    expect(events.any((event) => event.incomeAmount != null), isTrue);
    expect(events.any((event) => event.pomodoroEnabled), isTrue);
    expect(events.any((event) => event.entrySource.isScheduleRelated), isTrue);

    final nestedChecklist = events.firstWhere(
      (event) => event.kind == CalendarEntryKind.checklist,
    );
    expect(nestedChecklist.checklist, isNotEmpty);
    expect(
      nestedChecklist.checklist.any((item) => item.children.isNotEmpty),
      isTrue,
    );
    expect(nestedChecklist.checklistTotalCount, greaterThan(3));
  });

  test('timed events have end after start and parseable HH:mm', () {
    final timePattern = RegExp(r'^\d{2}:\d{2}$');
    for (final event in events.where((event) => event.isTimed)) {
      expect(event.end.isAfter(event.start), isTrue, reason: event.id);
      expect(event.startTime, matches(timePattern), reason: event.id);
      expect(event.endTime, matches(timePattern), reason: event.id);
      expect(event.title, isNotEmpty, reason: event.id);
    }
  });

  test('personal timed events do not overlap each other', () {
    final personal = events
        .where(
          (event) =>
              event.kind == CalendarEntryKind.event &&
              !event.entrySource.isScheduleRelated,
        )
        .toList();
    final expanded = RecurrenceEngine.expandAll(
      personal,
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2027, 1, 1),
    );

    final byDay = <DateTime, List<AppEvent>>{};
    for (final event in expanded) {
      final key = DateTime(
        event.start.year,
        event.start.month,
        event.start.day,
      );
      byDay.putIfAbsent(key, () => []).add(event);
    }

    for (final dayEvents in byDay.values) {
      for (var i = 0; i < dayEvents.length; i++) {
        for (var j = i + 1; j < dayEvents.length; j++) {
          expect(
            timeRangesOverlap(
              dayEvents[i].start,
              dayEvents[i].end,
              dayEvents[j].start,
              dayEvents[j].end,
            ),
            isFalse,
            reason: '${dayEvents[i].id} vs ${dayEvents[j].id}',
          );
        }
      }
    }
  });

  test('only the documented personal event overlaps a generated shift', () {
    final personal = events
        .where(
          (event) =>
              event.kind == CalendarEntryKind.event &&
              !event.entrySource.isScheduleRelated,
        )
        .toList();
    final expandedPersonal = RecurrenceEngine.expandAll(
      personal,
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2027, 1, 1),
    );
    final generated = CyclicScheduleEventGenerator.expandForRange(
      schedules: schedules,
      rangeStart: DateTime(2026, 1, 1),
      rangeEnd: DateTime(2027, 1, 1),
    );

    final overlapping = expandedPersonal.where((event) {
      return generated.any(
        (shift) =>
            eventsOnSameDay(event.start, shift.start) &&
            timeRangesOverlap(event.start, event.end, shift.start, shift.end),
      );
    }).toList();

    expect(overlapping, isNotEmpty);
    expect(
      overlapping.map((event) => event.id),
      everyElement(TestCalendarFill.conflictEventId),
    );
  });

  test('schedules and savings goals stay within editor rules', () {
    for (final schedule in schedules) {
      expect(schedule.profileId, profileId);
      expect(schedule.title, isNotEmpty);
      final start = _minutes(schedule.startTime);
      final end = _minutes(schedule.endTime);
      expect(end, greaterThan(start), reason: schedule.id);
      if (schedule.isShiftCycle) {
        expect(schedule.workDays, greaterThan(0));
        expect(schedule.restDays, greaterThan(0));
        expect(schedule.cycleStartDate, isNotNull);
      } else {
        expect(schedule.rrule, isNotEmpty);
      }
    }

    final office = schedules.firstWhere(
      (schedule) => schedule.id == TestCalendarFill.officeScheduleId,
    );
    final shift = schedules.firstWhere(
      (schedule) => schedule.id == TestCalendarFill.shiftScheduleId,
    );
    expect(
      _minutes(shift.startTime),
      greaterThanOrEqualTo(_minutes(office.endTime)),
    );

    for (final goal in goals) {
      expect(goal.profileId, profileId);
      expect(goal.title, isNotEmpty);
      expect(goal.targetAmount, greaterThan(0));
      expect(goal.savedAmount, greaterThanOrEqualTo(0));
      expect(goal.savedAmount, lessThan(goal.targetAmount));
      expect(goal.monthlyLivingExpenses, greaterThanOrEqualTo(0));
    }
  });

  test('overrides belong to real shift days and keep quick-actions usable', () {
    final overrides = events
        .where(
          (event) => event.entrySource == CalendarEntrySource.scheduleOverride,
        )
        .toList();
    expect(overrides, isNotEmpty);
    expect(overrides.any((event) => event.shiftSkipped), isTrue);
    expect(overrides.any((event) => event.overtimeMinutes != null), isTrue);

    for (final override in overrides) {
      final scheduleId = override.workScheduleId;
      expect(scheduleId, isNotNull, reason: override.id);
      final schedule = schedules.firstWhere((item) => item.id == scheduleId);
      expect(override.seriesId, 'schedule-$scheduleId');
      expect(
        override.id,
        AppEvent.scheduleOverrideId(scheduleId!, override.start),
      );
      expect(override.capabilities.editsCreateScheduleOverride, isTrue);
      expect(override.capabilities.canRevertOverride, isTrue);

      if (schedule.isShiftCycle) {
        expect(
          isShiftWorkDay(
            cycleStartDate: schedule.cycleStartDate!,
            workDays: schedule.workDays,
            restDays: schedule.restDays,
            date: override.start,
          ),
          isTrue,
          reason: override.id,
        );
      } else {
        expect(override.start.weekday, lessThanOrEqualTo(DateTime.friday));
      }

      final skipped = applyShiftQuickActionPatch(
        source: override,
        action: ShiftQuickAction.toggleSkip,
      );
      expect(skipped.shiftSkipped, isNot(override.shiftSkipped));
    }
  });

  test('recurrence until is after start and exclusions remove that day', () {
    for (final event in events.where((event) => event.hasRecurrence)) {
      expect(event.seriesId, event.id);
      expect(event.recurrenceUntil, isNotNull, reason: event.id);
      expect(
        event.recurrenceUntil!.isAfter(event.start),
        isTrue,
        reason: event.id,
      );
    }

    final daily = events.firstWhere(
      (event) => event.id == TestCalendarFill.dailySeriesId,
    );
    expect(daily.recurrenceExclusions, isNotEmpty);
    final excluded = daily.recurrenceExclusions.first;
    final expanded = RecurrenceEngine.expandEvent(
      daily,
      rangeStart: DateTime(excluded.year, excluded.month, excluded.day),
      rangeEnd: DateTime(
        excluded.year,
        excluded.month,
        excluded.day,
      ).add(const Duration(days: 1)),
    );
    expect(expanded, isEmpty);
  });

  test('notes include explicit and auto-derived titles', () {
    final notes = events
        .where((event) => event.kind == CalendarEntryKind.note)
        .toList();
    expect(notes.any((event) => event.isAutoDerivedNoteTitle), isTrue);
    expect(notes.any((event) => !event.isAutoDerivedNoteTitle), isTrue);
    for (final note in notes) {
      expect(note.notes, isNotNull);
      expect(note.notes!.trim(), isNotEmpty);
      if (!note.isAutoDerivedNoteTitle) {
        expect(note.noteDisplaySecondary, isNotNull);
      }
    }

    final longNote = notes.firstWhere(
      (event) => (event.notes?.length ?? 0) >= 220,
    );
    expect(longNote.noteDisplayTitle, isNotEmpty);
  });

  test('checklists have unique ids and non-empty titles', () {
    for (final event in events.where(
      (event) => event.kind == CalendarEntryKind.checklist,
    )) {
      final ids = <String>{};
      void walk(List<ChecklistItem> items) {
        for (final item in items) {
          expect(item.title.trim(), isNotEmpty, reason: item.id);
          expect(ids.add(item.id), isTrue, reason: item.id);
          walk(item.children);
        }
      }

      walk(event.checklist);
    }
  });

  test('snapshot codec round-trips fill data and year expansion loads', () {
    final snapshot = LocalDataSnapshot(
      profiles: const [ContextProfile(id: profileId, name: 'Тест')],
      activeProfileId: profileId,
      visibleProfileIds: const {profileId},
      eventsByProfile: {profileId: events},
      schedulesByProfile: {profileId: schedules},
      templatesByProfile: const {},
      requestsByProfile: const {},
      savingsGoalsByProfile: {
        profileId: TestCalendarFill.savingsGoals(
          profileId,
          year: 2026,
          now: now,
        ),
      },
    );

    final restored = LocalDataSnapshot.fromJson(snapshot.toJson());
    expect(restored.eventsByProfile[profileId], hasLength(events.length));
    expect(restored.schedulesByProfile[profileId], hasLength(schedules.length));
    expect(restored.savingsGoalsByProfile[profileId], hasLength(4));

    final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
      seedDemoData: false,
    );
    scheduleRepo.restoreSchedulesByProfile(restored.schedulesByProfile);
    final eventRepo = InMemoryEventRepository(
      scheduleRepository: scheduleRepo,
      seedDemoData: false,
    );
    eventRepo.restoreEventsByProfile(restored.eventsByProfile);

    final expanded = eventRepo.getEventsForYear(
      profileId: profileId,
      year: 2026,
    );
    expect(expanded, isNotEmpty);
    expect(
      expanded.any((event) => event.kind == CalendarEntryKind.event),
      isTrue,
    );
    expect(
      expanded.any((event) => event.entrySource.isScheduleRelated),
      isTrue,
    );

    final months = expanded.map((event) => event.start.month).toSet();
    expect(months.length, 12);
  });

  test('fill stays on the given profile id', () {
    expect(
      events.every(
        (event) =>
            event.contextProfileId == null ||
            event.contextProfileId == profileId,
      ),
      isTrue,
    );
    expect(
      schedules.every((schedule) => schedule.profileId == profileId),
      isTrue,
    );
    expect(goals.every((goal) => goal.profileId == profileId), isTrue);
  });
}

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
