import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/services/calendar_event_service.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:almanac/data/schedules/cyclic_work_schedule_repository.dart';

void main() {
  group('shiftEventToCalendarDate', () {
    test('moves timed event keeping clock times', () {
      final event = AppEvent(
        id: 'e1',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 7, 14),
          end: DateTime(2026, 6, 22, 12),
        ),
        title: 'Task',
        startTime: '07:14',
        endTime: '12:00',
        color: Colors.blue,
        interaction: EventInteraction.allowNone(),
      );

      final moved = shiftEventToCalendarDate(event, DateTime(2026, 6, 24));

      expect(moved.isOnDate(DateTime(2026, 6, 24)), isTrue);
      expect(moved.start.toLocal().hour, 7);
      expect(moved.start.toLocal().minute, 14);
      expect(moved.startTime, '07:14');
    });

    test('moves note to date-only range', () {
      final event = AppEvent(
        id: 'note-1',
        dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 6, 22)),
        title: 'Note',
        startTime: '',
        endTime: '',
        color: Colors.grey,
        kind: CalendarEntryKind.note,
        notes: 'Hello',
        interaction: EventInteraction.allowNone(),
      );

      final moved = shiftEventToCalendarDate(event, DateTime(2026, 6, 25));

      expect(moved.isOnDate(DateTime(2026, 6, 25)), isTrue);
      expect(moved.notes, 'Hello');
    });
  });

  group('CalendarEventService.movePersonalEventToDate', () {
    test('rejects guest calendar events', () {
      final repo = InMemoryEventRepository();
      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      final guest = AppEvent(
        id: 'guest-1',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 8),
          end: DateTime(2026, 6, 22, 9),
        ),
        title: 'Guest',
        startTime: '08:00',
        endTime: '09:00',
        color: Colors.grey,
        explicitEntrySource: CalendarEntrySource.guestCalendar,
        interaction: EventInteraction.allowNone(),
      );

      expect(
        () => service.movePersonalEventToDate(
          event: guest,
          targetDate: DateTime(2026, 6, 23),
        ),
        throwsStateError,
      );
    });

    test('moves work shift as a schedule override', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      final day = DateTime(2026, 6, 22);
      final scheduleEvent = AppEvent(
        id: 'schedule-sched-1-${day.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 8),
          end: DateTime(2026, 6, 22, 17),
        ),
        title: 'Shift',
        startTime: '08:00',
        endTime: '17:00',
        color: Colors.red,
        seriesId: 'schedule-sched-1',
        interaction: EventInteraction.allowNone(),
      );

      final result = service.movePersonalEventToDateTime(
        event: scheduleEvent,
        targetDate: DateTime(2026, 6, 22),
        startTime: const TimeOfDay(hour: 9, minute: 0),
      );

      expect(result, isNotNull);
      expect(result!.kind, WeekEventPersistKind.overrideCreated);
      final masters = repo.getMasterEvents(profileId: 'default');
      expect(masters, hasLength(1));
      expect(masters.first.isScheduleOccurrenceOverride, isTrue);
      expect(masters.first.startTime, '09:00');
      expect(masters.first.endTime, '18:00');
    });

    test('undo restores a newly created shift override', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      final day = DateTime(2026, 6, 22);
      final scheduleEvent = AppEvent(
        id: 'schedule-sched-1-${day.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 8),
          end: DateTime(2026, 6, 22, 17),
        ),
        title: 'Shift',
        startTime: '08:00',
        endTime: '17:00',
        color: Colors.red,
        seriesId: 'schedule-sched-1',
        interaction: EventInteraction.allowNone(),
      );

      final result = service.movePersonalEventToDateTime(
        event: scheduleEvent,
        targetDate: DateTime(2026, 6, 22),
        startTime: const TimeOfDay(hour: 10, minute: 0),
      )!;
      expect(repo.getMasterEvents(profileId: 'default'), hasLength(1));

      service.undoWeekEventMove(result);
      expect(repo.getMasterEvents(profileId: 'default'), isEmpty);
    });

    test('undo restores personal event time', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final event = AppEvent(
        id: 'personal-undo',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 10),
          end: DateTime(2026, 6, 22, 11),
        ),
        title: 'Meet',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      );
      repo.addEvent(profileId: 'default', event: event);

      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      final result = service.movePersonalEventToDateTime(
        event: event,
        targetDate: DateTime(2026, 6, 23),
        startTime: const TimeOfDay(hour: 14, minute: 0),
      )!;
      var moved = repo
          .getMasterEvents(profileId: 'default')
          .firstWhere((item) => item.id == 'personal-undo');
      expect(moved.startTime, '14:00');

      service.undoWeekEventMove(result);
      moved = repo
          .getMasterEvents(profileId: 'default')
          .firstWhere((item) => item.id == 'personal-undo');
      expect(moved.isOnDate(DateTime(2026, 6, 22)), isTrue);
      expect(moved.startTime, '10:00');
    });

    test('moves personal event to another day', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final event = AppEvent(
        id: 'personal-1',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 10),
          end: DateTime(2026, 6, 22, 11),
        ),
        title: 'Meet',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      );
      repo.addEvent(profileId: 'default', event: event);

      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      service.movePersonalEventToDate(
        event: event,
        targetDate: DateTime(2026, 6, 24),
      );

      final masters = repo.getMasterEvents(profileId: 'default');
      expect(masters.where((e) => e.id == 'personal-1').length, 1);
      expect(
        masters
            .firstWhere((e) => e.id == 'personal-1')
            .isOnDate(DateTime(2026, 6, 24)),
        isTrue,
      );
    });
  });

  group('CalendarEventService.movePersonalEventToDateTime', () {
    test('keeps duration when moving to a new start time', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final event = AppEvent(
        id: 'personal-2',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 10),
          end: DateTime(2026, 6, 22, 11, 30),
        ),
        title: 'Meet',
        startTime: '10:00',
        endTime: '11:30',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      );
      repo.addEvent(profileId: 'default', event: event);

      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      service.movePersonalEventToDateTime(
        event: event,
        targetDate: DateTime(2026, 6, 23),
        startTime: const TimeOfDay(hour: 14, minute: 15),
      );

      final moved = repo
          .getMasterEvents(profileId: 'default')
          .firstWhere((e) => e.id == 'personal-2');
      expect(moved.isOnDate(DateTime(2026, 6, 23)), isTrue);
      expect(moved.startTime, '14:15');
      expect(moved.endTime, '15:45');
    });

    test('allows drop onto a conflicting timed event', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final first = AppEvent(
        id: 'busy',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 23, 14),
          end: DateTime(2026, 6, 23, 15),
        ),
        title: 'Busy',
        startTime: '14:00',
        endTime: '15:00',
        color: Colors.orange,
        interaction: EventInteraction.allowNone(),
      );
      final moving = AppEvent(
        id: 'moving',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 10),
          end: DateTime(2026, 6, 22, 11),
        ),
        title: 'Moving',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      );
      repo.addEvent(profileId: 'default', event: first);
      repo.addEvent(profileId: 'default', event: moving);

      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      service.movePersonalEventToDateTime(
        event: moving,
        targetDate: DateTime(2026, 6, 23),
        startTime: const TimeOfDay(hour: 14, minute: 0),
      );

      final moved = repo
          .getMasterEvents(profileId: 'default')
          .firstWhere((e) => e.id == 'moving');
      expect(moved.isOnDate(DateTime(2026, 6, 23)), isTrue);
      expect(moved.startTime, '14:00');
      expect(moved.endTime, '15:00');
    });
  });

  group('CalendarEventService.resizePersonalEvent', () {
    test('persists snapped duration', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final event = AppEvent(
        id: 'personal-3',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 10),
          end: DateTime(2026, 6, 22, 11),
        ),
        title: 'Meet',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      );
      repo.addEvent(profileId: 'default', event: event);

      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      service.resizePersonalEvent(
        event: event,
        startMinutes: 10 * 60 + 7,
        endMinutes: 12 * 60 + 8,
      );

      final resized = repo
          .getMasterEvents(profileId: 'default')
          .firstWhere((e) => e.id == 'personal-3');
      expect(resized.startTime, '10:00');
      expect(resized.endTime, '12:15');
    });

    test('resizes work shift as a schedule override', () {
      final scheduleRepo = InMemoryCyclicWorkScheduleRepository(
        seedDemoData: false,
      );
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepo,
        seedDemoData: false,
      );
      final combined = CombinedEventRepository(repo, {'default'});
      final service = CalendarEventService(
        eventRepository: repo,
        combinedRepository: combined,
        activeProfileId: 'default',
      );

      final day = DateTime(2026, 6, 22);
      final scheduleEvent = AppEvent(
        id: 'schedule-sched-1-${day.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 22, 8),
          end: DateTime(2026, 6, 22, 17),
        ),
        title: 'Shift',
        startTime: '08:00',
        endTime: '17:00',
        color: Colors.red,
        seriesId: 'schedule-sched-1',
        interaction: EventInteraction.allowNone(),
      );

      service.resizePersonalEvent(
        event: scheduleEvent,
        startMinutes: 8 * 60,
        endMinutes: 18 * 60,
      );

      final override = repo.getMasterEvents(profileId: 'default').single;
      expect(override.isScheduleOccurrenceOverride, isTrue);
      expect(override.endTime, '18:00');
    });
  });
}
