import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:almanac/booking/booking_repository.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/events/event_overlap.dart';
import 'package:almanac/data/events/recurrence_engine.dart';

AppEvent _event({
  required String id,
  required DateTime start,
  required DateTime end,
  String? rrule,
  String? seriesId,
  DateTime? recurrenceUntil,
}) {
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(start: start, end: end),
    title: 'Test',
    startTime: '09:00',
    endTime: '10:00',
    color: Colors.blue,
    rrule: rrule,
    seriesId: seriesId,
    recurrenceUntil: recurrenceUntil,
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  group('RecurrenceEngine', () {
    test('expands daily recurrence within range', () {
      final master = _event(
        id: 'series-1',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
        rrule: 'FREQ=DAILY;INTERVAL=1',
        seriesId: 'series-1',
      );

      final expanded = RecurrenceEngine.expandEvent(
        master,
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 5),
      );

      expect(expanded.length, 4);
      expect(expanded.first.start.toLocal(), DateTime(2026, 6, 1, 9));
      expect(expanded.last.start.toLocal(), DateTime(2026, 6, 4, 9));
      expect(expanded.every((e) => e.isRecurrenceOccurrence), isTrue);
    });

    test('respects recurrenceUntil end date', () {
      final master = _event(
        id: 'series-until',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
        rrule: 'FREQ=DAILY;INTERVAL=1',
        seriesId: 'series-until',
        recurrenceUntil: DateTime(2026, 6, 3, 23, 59, 59),
      );

      final expanded = RecurrenceEngine.expandEvent(
        master,
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 10),
      );

      expect(expanded.length, 3);
      expect(expanded.last.start.toLocal(), DateTime(2026, 6, 3, 9));
    });

    test('returns single event when no recurrence', () {
      final event = _event(
        id: 'single',
        start: DateTime(2026, 6, 10, 14),
        end: DateTime(2026, 6, 10, 15),
      );

      final expanded = RecurrenceEngine.expandEvent(
        event,
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 7, 1),
      );

      expect(expanded.length, 1);
      expect(expanded.first.id, 'single');
    });
  });

  group('Event overlap', () {
    test('detects overlapping events on same day', () {
      final existing = [
        _event(
          id: 'a',
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 10, 9, 30),
          candidateEnd: DateTime(2026, 6, 10, 10, 30),
          existingEvents: existing,
        ),
        isTrue,
      );
    });

    test('no conflict on different days', () {
      final existing = [
        _event(
          id: 'a',
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 11, 9),
          candidateEnd: DateTime(2026, 6, 11, 10),
          existingEvents: existing,
        ),
        isFalse,
      );
    });

    test('overnight candidate detects conflict on the next day', () {
      final existing = [
        _event(
          id: 'morning',
          start: DateTime(2026, 6, 11, 1),
          end: DateTime(2026, 6, 11, 2),
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 10, 22),
          candidateEnd: DateTime(2026, 6, 11, 3),
          existingEvents: existing,
        ),
        isTrue,
      );
    });

    test('abutting overnight end does not conflict', () {
      final existing = [
        _event(
          id: 'morning',
          start: DateTime(2026, 6, 11, 2),
          end: DateTime(2026, 6, 11, 3),
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 10, 22),
          candidateEnd: DateTime(2026, 6, 11, 2),
          existingEvents: existing,
        ),
        isFalse,
      );
    });

    test('detects conflict with expanded recurring event', () {
      final existing = [
        _event(
          id: 'standup',
          start: DateTime(2026, 6, 1, 9),
          end: DateTime(2026, 6, 1, 10),
          rrule: 'FREQ=DAILY;INTERVAL=1',
          seriesId: 'standup',
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 3, 9, 30),
          candidateEnd: DateTime(2026, 6, 3, 10, 30),
          existingEvents: existing,
        ),
        isTrue,
      );
    });

    test('excludes series when editing master event', () {
      final existing = [
        _event(
          id: 'standup',
          start: DateTime(2026, 6, 1, 9),
          end: DateTime(2026, 6, 1, 10),
          rrule: 'FREQ=DAILY;INTERVAL=1',
          seriesId: 'standup',
        ),
      ];

      expect(
        hasEventConflict(
          candidateStart: DateTime(2026, 6, 1, 9),
          candidateEnd: DateTime(2026, 6, 1, 10),
          existingEvents: existing,
          excludeSeriesId: 'standup',
        ),
        isFalse,
      );
    });

    test('schedule edit ignores conflict with same schedule occurrence', () {
      final day = DateTime(2026, 6, 3, 8);
      final scheduleEvent = AppEvent(
        id: 'schedule-shift-${day.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(start: day, end: DateTime(2026, 6, 3, 17)),
        title: 'Смена',
        startTime: '08:00',
        endTime: '17:00',
        color: Colors.teal,
        seriesId: 'schedule-shift',
        interaction: EventInteraction.allowNone(),
      );

      final conflicts = findScheduleEditConflicts(
        candidateStart: scheduleEvent.start,
        candidateEnd: DateTime(2026, 6, 3, 20),
        existingEvents: [scheduleEvent],
        editingEvent: scheduleEvent,
      );

      expect(conflicts, isEmpty);
    });

    test('schedule edit still detects personal event conflict', () {
      final day = DateTime(2026, 6, 3, 8);
      final scheduleEvent = AppEvent(
        id: 'schedule-shift-${day.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(start: day, end: DateTime(2026, 6, 3, 17)),
        title: 'Смена',
        startTime: '08:00',
        endTime: '17:00',
        color: Colors.teal,
        seriesId: 'schedule-shift',
        interaction: EventInteraction.allowNone(),
      );
      final personal = _event(
        id: 'meet',
        start: DateTime(2026, 6, 3, 18),
        end: DateTime(2026, 6, 3, 19),
      );

      final conflicts = findScheduleEditConflicts(
        candidateStart: scheduleEvent.start,
        candidateEnd: DateTime(2026, 6, 3, 20),
        existingEvents: [scheduleEvent, personal],
        editingEvent: scheduleEvent,
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.first.id, 'meet');
    });
  });

  group('BookingRepository', () {
    late InMemoryBookingRepository repo;
    const profileId = 'default';

    setUp(() {
      repo = InMemoryBookingRepository();
    });

    test('finds template by token', () {
      expect(
        repo.findTemplateByToken(profileId: profileId, token: 'demo'),
        isNotNull,
      );
      expect(
        repo.findTemplateByToken(profileId: profileId, token: 'missing'),
        isNull,
      );
    });

    test('returns available slots excluding busy ones', () {
      final day = DateTime(2026, 6, 25);
      final slotsBefore = repo.getSlots(
        profileId: profileId,
        templateToken: 'demo',
        day: day,
      );
      final availableBefore = slotsBefore
          .where((s) => s.available)
          .toList(growable: false);

      expect(availableBefore, isNotEmpty);

      final slot = availableBefore.first;
      repo.createRequest(
        profileId: profileId,
        templateToken: 'demo',
        start: slot.start,
        end: slot.end,
        confirmationMode: BookingConfirmationMode.manual,
      );

      final slotsAfter = repo.getSlots(
        profileId: profileId,
        templateToken: 'demo',
        day: day,
      );
      final sameSlot = slotsAfter.firstWhere((s) => s.start == slot.start);
      expect(sameSlot.available, isFalse);
    });

    test('auto confirmation sets confirmed status', () {
      final day = DateTime(2026, 6, 26);
      final slot = repo
          .getSlots(profileId: profileId, templateToken: 'demo', day: day)
          .firstWhere((s) => s.available);

      final request = repo.createRequest(
        profileId: profileId,
        templateToken: 'demo',
        start: slot.start,
        end: slot.end,
        confirmationMode: BookingConfirmationMode.automatic,
      );

      expect(request.status, BookingRequestStatus.confirmed);
    });

    test('manual confirmation creates pending request', () {
      final day = DateTime(2026, 6, 27);
      final slot = repo
          .getSlots(profileId: profileId, templateToken: 'demo', day: day)
          .firstWhere((s) => s.available);

      final request = repo.createRequest(
        profileId: profileId,
        templateToken: 'demo',
        start: slot.start,
        end: slot.end,
        confirmationMode: BookingConfirmationMode.manual,
      );

      expect(request.status, BookingRequestStatus.pending);
      expect(
        repo
            .getPendingRequests(profileId: profileId)
            .any((r) => r.id == request.id),
        isTrue,
      );
    });

    test('rejection keeps status without creating side effects', () {
      final pending = repo.getPendingRequests(profileId: profileId).first;
      final updated = repo.updateRequestStatus(
        profileId: profileId,
        requestId: pending.id,
        status: BookingRequestStatus.rejected,
      );

      expect(updated.status, BookingRequestStatus.rejected);
      expect(
        repo
            .getPendingRequests(profileId: profileId)
            .any((r) => r.id == pending.id),
        isFalse,
      );
    });
  });
}
