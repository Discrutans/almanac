import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/event_domain_state.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/note_attachment.dart';
import 'package:almanac/data/local/local_data_codec.dart';

void main() {
  test('AppEvent forwards flat fields to nested domain state', () {
    final event = AppEvent(
      id: 'nested',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
      ),
      title: 'Nested state',
      startTime: '09:00',
      endTime: '10:00',
      color: const Color(0xFF0000FF),
      pomodoro: const EventPomodoroState(enabled: true, workMinutes: 40),
      finance: const EventFinanceState(incomeAmount: 100),
      shiftPay: const EventShiftPayState(overtimeMinutes: 15),
      interaction: EventInteraction.allowNone(),
    );

    expect(event.pomodoroEnabled, isTrue);
    expect(event.pomodoroWorkMinutes, 40);
    expect(event.incomeAmount, 100);
    expect(event.overtimeMinutes, 15);

    final updated = event.copyWith(
      pomodoroWorkMinutes: 50,
      clearIncomeAmount: true,
    );
    expect(updated.pomodoro.workMinutes, 50);
    expect(updated.finance.incomeAmount, isNull);
  });

  test('LocalDataCodec roundtrips entry kind', () {
    final note = AppEvent(
      id: 'note-1',
      kind: CalendarEntryKind.note,
      dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 6, 2)),
      title: 'Shopping',
      startTime: '',
      endTime: '',
      color: const Color(0xFF00AA00),
      notes: 'Buy milk',
      interaction: EventInteraction.allowNone(),
    );

    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [note],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();

    final restored = LocalDataSnapshot.fromJson(
      json,
    ).eventsByProfile['default']!.single;
    expect(restored.kind, CalendarEntryKind.note);
    expect(restored.notes, 'Buy milk');
  });

  test('LocalDataCodec roundtrips notes and reminder fields', () {
    final event = AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
      ),
      title: 'Meeting',
      startTime: '09:00',
      endTime: '10:00',
      color: const Color(0xFF0000FF),
      notes: 'Bring docs',
      reminderMinutesBefore: 15,
      overtimeMinutes: 30,
      interaction: EventInteraction.allowNone(),
    );

    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [event],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();

    final restored = LocalDataSnapshot.fromJson(json);
    final restoredEvent = restored.eventsByProfile['default']!.single;

    expect(restoredEvent.notes, 'Bring docs');
    expect(restoredEvent.reminderMinutesBefore, 15);
    expect(restoredEvent.overtimeMinutes, 30);
  });

  test('LocalDataCodec roundtrips amount field', () {
    final event = AppEvent(
      id: 'e-finance',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 3, 14),
        end: DateTime(2026, 6, 3, 15),
      ),
      title: 'Client project',
      startTime: '14:00',
      endTime: '15:00',
      color: const Color(0xFF00AA00),
      notes: 'Landing page',
      incomeAmount: 5000,
      interaction: EventInteraction.allowNone(),
    );

    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [event],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();

    final restored = LocalDataSnapshot.fromJson(
      json,
    ).eventsByProfile['default']!.single;
    expect(restored.incomeAmount, 5000);
    expect(restored.notes, 'Landing page');
  });

  test('parsePersonalEventTimes allows empty end time', () {
    final parsed = parsePersonalEventTimes(startRaw: '09:30', endRaw: '');
    expect(parsed, isNotNull);
    expect(parsed!.start, const TimeOfDay(hour: 9, minute: 30));
    expect(parsed.end, isNull);

    final range = buildPersonalEventDateTimeRange(
      day: DateTime(2026, 6, 5),
      start: parsed.start,
      end: parsed.end,
    );
    expect(range.end.difference(range.start), openEndedEventDuration);
    expect(
      formatEventTimeRange(
        AppEvent(
          id: 'open',
          dateTimeRange: range,
          title: 'Call',
          startTime: '09:30',
          endTime: '',
          color: const Color(0xFF0000FF),
          interaction: EventInteraction.allowNone(),
        ),
      ),
      '09:30',
    );
  });

  test('LocalDataCodec roundtrips pomodoro and attachments', () {
    final event = AppEvent(
      id: 'e-advanced',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 4, 10),
        end: DateTime(2026, 6, 4, 11),
      ),
      title: 'Deep work',
      startTime: '10:00',
      endTime: '11:00',
      color: const Color(0xFF0000FF),
      pomodoroEnabled: true,
      pomodoroWorkMinutes: 30,
      pomodoroBreakMinutes: 10,
      pomodoroCompletedSessions: 2,
      pomodoroRemainingSeconds: 17 * 60 + 30,
      pomodoroOnBreak: true,
      attachments: const [
        NoteAttachment(
          id: 'a1',
          fileName: 'scan.pdf',
          storagePath: 'note-1/a1.pdf',
          mimeType: 'application/pdf',
        ),
      ],
      interaction: EventInteraction.allowNone(),
    );

    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [event],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();

    final restored = LocalDataSnapshot.fromJson(
      json,
    ).eventsByProfile['default']!.single;
    expect(restored.pomodoroEnabled, isTrue);
    expect(restored.pomodoroWorkMinutes, 30);
    expect(restored.pomodoroBreakMinutes, 10);
    expect(restored.pomodoroCompletedSessions, 2);
    expect(restored.pomodoroRemainingSeconds, 17 * 60 + 30);
    expect(restored.pomodoroOnBreak, isTrue);
    expect(restored.attachments, hasLength(1));
    expect(restored.attachments.first.fileName, 'scan.pdf');
  });

  test('dateOnlyRange keeps local calendar day for UTC timestamps', () {
    // Local Jul 31 00:00 in UTC+3 is stored as Jul 30 21:00Z.
    final utcStart = DateTime.utc(2026, 7, 30, 21);
    final range = AppEvent.dateOnlyRange(utcStart);

    expect(calendarDayKey(range.start), calendarDayKey(utcStart));
    expect(range.start.year, 2026);
    expect(range.start.month, 7);
    expect(range.start.day, calendarDayKey(utcStart).day);
  });

  test('checklist toggle preserves calendar day', () {
    final utcStart = DateTime.utc(2026, 7, 30, 21);
    final event = AppEvent(
      id: 'cl-utc',
      kind: CalendarEntryKind.checklist,
      dateTimeRange: AppEvent.dateOnlyRange(utcStart),
      title: 'Tasks',
      startTime: '',
      endTime: '',
      color: const Color(0xFF0000FF),
      checklist: const [ChecklistItem(id: 'c1', title: 'Task')],
      interaction: EventInteraction.allowNone(),
    );

    final toggled = event.copyWith(
      checklist: [
        const ChecklistItem(id: 'c1', title: 'Task', completed: true),
      ],
    );

    expect(calendarDayKey(toggled.start), calendarDayKey(utcStart));
  });

  test('checklist save path preserves calendar day', () {
    final utcStart = DateTime.utc(2026, 7, 30, 21);
    final event = AppEvent(
      id: 'cl-save',
      kind: CalendarEntryKind.checklist,
      dateTimeRange: DateTimeRange(
        start: utcStart,
        end: utcStart.add(const Duration(minutes: 1)),
      ),
      title: 'Tasks',
      startTime: '',
      endTime: '',
      color: const Color(0xFF0000FF),
      checklist: const [ChecklistItem(id: 'c1', title: 'Task')],
      interaction: EventInteraction.allowNone(),
    );

    final eventDate = calendarDayKey(event.start);
    final saved = event.copyWith(
      checklist: [
        const ChecklistItem(id: 'c1', title: 'Task', completed: true),
      ],
      dateTimeRange: AppEvent.dateOnlyRange(eventDate),
    );

    expect(calendarDayKey(saved.start), calendarDayKey(utcStart));
  });

  test('checklist supports pomodoro timer', () {
    const checklist = ChecklistItem(id: 'c1', title: 'Task');
    final event = AppEvent(
      id: 'cl-1',
      kind: CalendarEntryKind.checklist,
      dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 7, 24)),
      title: 'Focus list',
      startTime: '',
      endTime: '',
      color: const Color(0xFF0000FF),
      checklist: const [checklist],
      pomodoroEnabled: true,
      pomodoroWorkMinutes: 25,
      pomodoroBreakMinutes: 5,
      interaction: EventInteraction.allowNone(),
    );

    expect(event.hasPomodoro, isTrue);

    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [event],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();

    final restored = LocalDataSnapshot.fromJson(
      json,
    ).eventsByProfile['default']!.single;
    expect(restored.kind, CalendarEntryKind.checklist);
    expect(restored.hasPomodoro, isTrue);
    expect(restored.pomodoroWorkMinutes, 25);
  });
}
