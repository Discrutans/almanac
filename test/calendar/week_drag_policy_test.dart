import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drag_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event({
  required String id,
  CalendarEntrySource? source,
  String? rrule,
  bool occurrence = false,
  String start = '10:00',
  String end = '11:00',
  DateTime? day,
}) {
  final date = day ?? DateTime(2026, 9, 8);
  final startParts = start.split(':');
  final endParts = end.split(':');
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      ),
      end: DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(endParts[0]),
        int.parse(endParts[1]),
      ),
    ),
    title: id,
    startTime: start,
    endTime: end,
    color: Colors.teal,
    rrule: rrule,
    seriesId: rrule == null ? null : id.split('-').first,
    isRecurrenceOccurrence: occurrence,
    explicitEntrySource: source,
  );
}

void main() {
  test('personal without series drags immediately', () {
    final event = _event(id: 'personal');
    expect(event.capabilities.weekDragImmediate, isTrue);
    expect(event.capabilities.canUnlockForWeekMove, isFalse);
    expect(weekEventShowsLock(event, lockedByOther: false, armed: false), isFalse);
  });

  test('series occurrence is unlockable', () {
    final event = _event(
      id: 'series-1',
      rrule: 'FREQ=DAILY;INTERVAL=1',
      occurrence: true,
    );
    expect(event.capabilities.canDragInWeekView, isFalse);
    expect(event.capabilities.canUnlockForWeekMove, isTrue);
    expect(weekEventShowsLock(event, lockedByOther: false, armed: false), isTrue);
    expect(weekEventShowsLock(event, lockedByOther: false, armed: true), isFalse);
  });

  test('schedule shift is unlockable, guest is forever locked', () {
    final shift = _event(
      id: 'schedule-abc-${DateTime(2026, 9, 8).millisecondsSinceEpoch}',
      source: CalendarEntrySource.scheduleGenerated,
    );
    final guest = _event(
      id: 'guest-1',
      source: CalendarEntrySource.guestCalendar,
    );
    final slot = _event(
      id: AppEvent.bookingSlotEventId('tok', 'slot'),
      source: CalendarEntrySource.bookingSlot,
    );

    expect(shift.capabilities.canUnlockForWeekMove, isTrue);
    expect(guest.capabilities.canUnlockForWeekMove, isFalse);
    expect(guest.capabilities.canMoveOnWeekGrid, isFalse);
    expect(slot.capabilities.canMoveOnWeekGrid, isFalse);
    expect(weekDragIsForeverLocked(guest, lockedByOther: false), isTrue);
    expect(weekDragCanUnlock(shift, lockedByOther: true), isFalse);
  });

  test('booking is unlockable on the week grid', () {
    final booking = _event(
      id: AppEvent.bookingEventId('req-1'),
      source: CalendarEntrySource.booking,
    );
    expect(booking.capabilities.canUnlockForWeekMove, isTrue);
    expect(booking.capabilities.weekDragImmediate, isFalse);
  });

  test('weekDropConflicts detects overlap; abutting is free', () {
    final moving = _event(id: 'a', start: '10:00', end: '11:00');
    final other = _event(id: 'b', start: '11:00', end: '13:00');
    expect(
      weekDropConflicts(
        event: moving,
        targetDate: DateTime(2026, 9, 8),
        startTime: const TimeOfDay(hour: 11, minute: 0),
        existingEvents: [moving, other],
      ),
      isTrue,
    );
    expect(
      weekDropConflicts(
        event: moving,
        targetDate: DateTime(2026, 9, 8),
        startTime: const TimeOfDay(hour: 13, minute: 0),
        existingEvents: [moving, other],
      ),
      isFalse,
    );
  });
}
