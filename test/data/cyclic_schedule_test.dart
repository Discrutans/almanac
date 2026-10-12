import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/core/config/app_config.dart';
import 'package:almanac/data/profiles/context_profile.dart';
import 'package:almanac/data/schedules/cyclic_schedule_generator.dart';
import 'package:almanac/data/schedules/cyclic_work_schedule_repository.dart';

void main() {
  group('CyclicScheduleEventGenerator', () {
    const rruleSchedule = CyclicWorkSchedule(
      id: 'sched-test',
      profileId: 'default',
      title: 'Будни',
      kind: CyclicScheduleKind.rrule,
      rrule: 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR',
      startTime: '09:00',
      endTime: '10:00',
      colorValue: 0xFF009688,
    );

    final shiftSchedule = CyclicWorkSchedule(
      id: 'sched-shift-22',
      profileId: 'default',
      title: 'Смена 2/2',
      kind: CyclicScheduleKind.shiftCycle,
      cycleStartDate: DateTime(2026, 6, 1),
      workDays: 2,
      restDays: 2,
      startTime: '08:00',
      endTime: '20:00',
      colorValue: 0xFF009688,
    );

    test('creates master event with rrule', () {
      final master = CyclicScheduleEventGenerator.toMasterEvent(rruleSchedule);

      expect(master.title, 'Будни');
      expect(master.rrule, rruleSchedule.rrule);
      expect(master.seriesId, 'schedule-sched-test');
    });

    test('expands weekday occurrences in range', () {
      final expanded = CyclicScheduleEventGenerator.expandForRange(
        schedules: const [rruleSchedule],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 8),
      );

      expect(expanded, isNotEmpty);
      expect(
        expanded.every((e) => e.id.startsWith('schedule-sched-test')),
        isTrue,
      );
    });

    test('expands 2/2 shift from start date', () {
      final expanded = CyclicScheduleEventGenerator.expandForRange(
        schedules: [shiftSchedule],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 9),
      );

      // 1-2 Jun work, 3-4 rest, 5-6 work, 7-8 rest
      expect(expanded.length, 4);
      expect(expanded.map((e) => e.start.day).toList(), [1, 2, 5, 6]);
    });

    test('expands 1/3 shift from start date', () {
      final schedule13 = CyclicWorkSchedule(
        id: 'sched-13',
        profileId: 'default',
        title: '1/3',
        kind: CyclicScheduleKind.shiftCycle,
        cycleStartDate: DateTime(2026, 6, 1),
        workDays: 1,
        restDays: 3,
        startTime: '09:00',
        endTime: '17:00',
        colorValue: 0xFF009688,
      );

      final expanded = CyclicScheduleEventGenerator.expandForRange(
        schedules: [schedule13],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 10),
      );

      // days 1, 5, 9 work (cycle length 4)
      expect(expanded.map((e) => e.start.day).toList(), [1, 5, 9]);
    });

    test('isShiftWorkDay helper', () {
      expect(
        isShiftWorkDay(
          cycleStartDate: DateTime(2026, 6, 1),
          workDays: 2,
          restDays: 2,
          date: DateTime(2026, 6, 2),
        ),
        isTrue,
      );
      expect(
        isShiftWorkDay(
          cycleStartDate: DateTime(2026, 6, 1),
          workDays: 2,
          restDays: 2,
          date: DateTime(2026, 6, 3),
        ),
        isFalse,
      );
    });
  });

  group('CyclicWorkScheduleRepository', () {
    test('seeds default profile with demo schedule', () {
      final repo = InMemoryCyclicWorkScheduleRepository();
      final schedules = repo.getForProfile('default');

      expect(schedules.length, 1);
      expect(schedules.first.title, contains('Планёрка'));
    });
  });

  group('AppConfig', () {
    test('defaults to local mode without dart-define', () {
      const config = AppConfig(
        serverUrl: '',
        enableRemoteSync: false,
        enableAutoRemoteSync: true,
        pushDeviceToken: '',
        seedDemoData: true,
      );

      expect(config.hasServer, isFalse);
      expect(config.remoteSyncEnabled, isFalse);
    });

    test('remote sync requires url and flag', () {
      const config = AppConfig(
        serverUrl: 'https://api.example.com',
        enableRemoteSync: true,
        enableAutoRemoteSync: true,
        pushDeviceToken: '',
        seedDemoData: true,
      );

      expect(config.remoteSyncEnabled, isTrue);
    });
  });
}
