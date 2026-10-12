import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/event_day_markers.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/data/schedules/cyclic_work_schedule_repository.dart';
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

void main() {
  group('LocalDataCodec', () {
    test('roundtrips snapshot json', () {
      final snapshot = LocalDataSnapshot(
        profiles: const [ContextProfile(id: 'default', name: 'Личный')],
        activeProfileId: 'default',
        visibleProfileIds: {'default'},
        eventsByProfile: {
          'default': [
            AppEvent(
              id: 'event-1',
              dateTimeRange: DateTimeRange(
                start: DateTime(2026, 6, 1, 9),
                end: DateTime(2026, 6, 1, 10),
              ),
              title: 'Test',
              startTime: '09:00',
              endTime: '10:00',
              color: Colors.blue,
              interaction: EventInteraction.allowNone(),
            ),
          ],
        },
        schedulesByProfile: {
          'default': [
            CyclicWorkSchedule(
              id: 'sched-1',
              profileId: 'default',
              title: '2/2',
              kind: CyclicScheduleKind.shiftCycle,
              cycleStartDate: DateTime(2026, 6, 1),
              workDays: 2,
              restDays: 2,
              startTime: '08:00',
              endTime: '20:00',
              colorValue: 0xFF009688,
            ),
          ],
        },
        templatesByProfile: const {},
        requestsByProfile: const {},
      );

      final restored = LocalDataSnapshot.decode(
        LocalDataSnapshot.encode(snapshot),
      );

      expect(restored.profiles.first.name, 'Личный');
      expect(restored.eventsByProfile['default']!.first.title, 'Test');
      expect(restored.schedulesByProfile['default']!.first.workDays, 2);
    });

    test('roundtrips localeLanguageCode', () {
      final snapshot = LocalDataSnapshot(
        profiles: const [ContextProfile(id: 'default', name: 'Personal')],
        activeProfileId: 'default',
        visibleProfileIds: {'default'},
        eventsByProfile: const {},
        schedulesByProfile: const {},
        templatesByProfile: const {},
        requestsByProfile: const {},
        localeLanguageCode: 'en',
      );

      final restored = LocalDataSnapshot.decode(
        LocalDataSnapshot.encode(snapshot),
      );

      expect(restored.localeLanguageCode, 'en');
    });

    test('roundtrips hideEmptyWeekHours', () {
      final snapshot = LocalDataSnapshot(
        profiles: const [ContextProfile(id: 'default', name: 'Personal')],
        activeProfileId: 'default',
        visibleProfileIds: {'default'},
        eventsByProfile: const {},
        schedulesByProfile: const {},
        templatesByProfile: const {},
        requestsByProfile: const {},
        hideEmptyWeekHours: false,
      );

      final restored = LocalDataSnapshot.decode(
        LocalDataSnapshot.encode(snapshot),
      );

      expect(restored.hideEmptyWeekHours, isFalse);
      expect(
        LocalDataSnapshot.decode(
          LocalDataSnapshot.encode(
            LocalDataSnapshot(
              profiles: const [ContextProfile(id: 'default', name: 'Personal')],
              activeProfileId: 'default',
              visibleProfileIds: {'default'},
              eventsByProfile: const {},
              schedulesByProfile: const {},
              templatesByProfile: const {},
              requestsByProfile: const {},
            ),
          ),
        ).hideEmptyWeekHours,
        isFalse,
      );
    });
  });

  group('AppEvent schedule helpers', () {
    test('detects schedule events and extracts schedule id', () {
      final event = AppEvent(
        id: 'schedule-sched-22-1710000000000',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 1, 8),
          end: DateTime(2026, 6, 1, 20),
        ),
        title: 'Смена',
        startTime: '08:00',
        endTime: '20:00',
        color: Colors.teal,
        seriesId: 'schedule-sched-22',
        interaction: EventInteraction.allowNone(),
      );

      expect(event.isFromWorkSchedule, isTrue);
      expect(event.workScheduleId, 'sched-22');
    });

    test('preserves numeric schedule id from seriesId', () {
      const scheduleId = 'sched-1734567890123456';
      final event = AppEvent(
        id: 'schedule-$scheduleId-1710000000000',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 1, 8),
          end: DateTime(2026, 6, 1, 20),
        ),
        title: 'Смена',
        startTime: '08:00',
        endTime: '20:00',
        color: Colors.teal,
        seriesId: 'schedule-$scheduleId',
        interaction: EventInteraction.allowNone(),
      );

      expect(event.workScheduleId, scheduleId);
    });
  });

  group('EventRepository delete', () {
    test('deletes user events but not schedule ids', () {
      final scheduleRepository = InMemoryCyclicWorkScheduleRepository();
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepository,
      );

      repo.ensureProfile('default');
      repo.addEvent(
        profileId: 'default',
        event: AppEvent(
          id: 'event-delete-me',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 8, 1, 9),
            end: DateTime(2026, 8, 1, 10),
          ),
          title: 'Temp',
          startTime: '09:00',
          endTime: '10:00',
          color: Colors.red,
          interaction: EventInteraction.allowNone(),
        ),
      );

      repo.deleteEvent(profileId: 'default', eventId: 'event-delete-me');
      repo.deleteEvent(profileId: 'default', eventId: 'schedule-any');

      expect(
        repo
            .getMasterEvents(profileId: 'default')
            .any((event) => event.id == 'event-delete-me'),
        isFalse,
      );
    });
  });

  group('Schedule occurrence overrides', () {
    test('override replaces generated schedule event for one day', () {
      final scheduleRepository = InMemoryCyclicWorkScheduleRepository();
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepository,
      );

      scheduleRepository.restoreSchedulesByProfile({
        'default': [
          CyclicWorkSchedule(
            id: 'sched-22',
            profileId: 'default',
            title: 'Смена',
            kind: CyclicScheduleKind.shiftCycle,
            cycleStartDate: DateTime(2026, 6, 1),
            workDays: 2,
            restDays: 2,
            startTime: '08:00',
            endTime: '20:00',
            colorValue: 0xFF009688,
          ),
        ],
      });
      repo.restoreEventsByProfile({'default': []});

      repo.upsertScheduleOverride(
        profileId: 'default',
        override: AppEvent(
          id: AppEvent.scheduleOverrideId('sched-22', DateTime(2026, 6, 1)),
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 1, 10),
            end: DateTime(2026, 6, 1, 12),
          ),
          title: 'Изменённая смена',
          startTime: '10:00',
          endTime: '12:00',
          color: Colors.orange,
          seriesId: 'schedule-sched-22',
          interaction: EventInteraction.allowNone(),
        ),
      );

      final events = repo.getEventsForRange(
        profileId: 'default',
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 2),
      );

      expect(events.length, 1);
      expect(events.first.title, 'Изменённая смена');
      expect(events.first.isScheduleOccurrenceOverride, isTrue);
    });

    test('schedule repository update changes generated events', () {
      final scheduleRepository = InMemoryCyclicWorkScheduleRepository();
      final repo = InMemoryEventRepository(
        scheduleRepository: scheduleRepository,
      );

      repo.ensureProfile('default');
      final schedule = scheduleRepository.getForProfile('default').first;

      scheduleRepository.update(
        profileId: 'default',
        schedule: schedule.copyWith(title: 'Обновлённая планёрка'),
      );

      final events = repo.getEventsForRange(
        profileId: 'default',
        rangeStart: DateTime(2026, 6, 2),
        rangeEnd: DateTime(2026, 6, 9),
      );

      expect(
        events.any((event) => event.title == 'Обновлённая планёрка'),
        isTrue,
      );
    });
  });

  group('EventDayMarkers', () {
    test('prioritizes active profile events for cell accent', () {
      final events = [
        AppEvent(
          id: 'work-1',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 1, 9),
            end: DateTime(2026, 6, 1, 10),
          ),
          title: 'Work',
          startTime: '09:00',
          endTime: '10:00',
          color: Colors.blue,
          contextProfileId: 'work',
          interaction: EventInteraction.allowNone(),
        ),
        AppEvent(
          id: 'personal-1',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 1, 11),
            end: DateTime(2026, 6, 1, 12),
          ),
          title: 'Personal',
          startTime: '11:00',
          endTime: '12:00',
          color: Colors.red,
          contextProfileId: 'default',
          interaction: EventInteraction.allowNone(),
        ),
      ];

      final accent = accentEventForProfile(events, 'default');
      expect(accent?.color, Colors.red);

      final ordered = prioritizeEventsForProfile(events, 'work');
      expect(ordered.first.contextProfileId, 'work');
    });
  });

  group('LocalDataStore', () {
    test('openInMemory seeds default profile data', () async {
      final store = await LocalDataStore.openInMemory();

      expect(store.profileRepository.getAll().length, 1);
      expect(
        store.eventRepository.getMasterEvents(profileId: 'default'),
        isNotEmpty,
      );
      expect(
        store.bookingRepository.findTemplateByToken(
          profileId: 'default',
          token: 'demo',
        ),
        isNotNull,
      );
    });

    test('openInMemory without demo data starts empty', () async {
      final store = await LocalDataStore.openInMemory(seedDemoData: false);

      expect(store.profileRepository.getAll().length, 1);
      expect(
        store.eventRepository.getMasterEvents(profileId: 'default'),
        isEmpty,
      );
      expect(store.scheduleRepository.getForProfile('default'), isEmpty);
      expect(
        store.bookingRepository.listTemplates(profileId: 'default'),
        isEmpty,
      );
    });
  });
}
