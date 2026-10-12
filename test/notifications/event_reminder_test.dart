import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/notifications/event_reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _event({
  required String id,
  required DateTime start,
  int? reminderMinutesBefore,
}) {
  final end = start.add(const Duration(hours: 1));
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(start: start, end: end),
    title: 'Test',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.blue,
    reminderMinutesBefore: reminderMinutesBefore,
  );
}

void main() {
  test('collectUpcomingEventReminders skips past and reminder-less events', () {
    final now = DateTime(2026, 6, 28, 12, 0);

    final candidates = collectUpcomingEventReminders(
      now: now,
      events: [
        _event(
          id: 'past',
          start: now.add(const Duration(hours: 1)),
          reminderMinutesBefore: 120,
        ),
        _event(
          id: 'future',
          start: now.add(const Duration(hours: 2)),
          reminderMinutesBefore: 30,
        ),
        _event(id: 'no-reminder', start: now.add(const Duration(hours: 3))),
      ],
    );

    expect(candidates, hasLength(1));
    expect(candidates.single.event.id, 'future');
    expect(
      candidates.single.fireAt.toLocal(),
      now.add(const Duration(hours: 2, minutes: -30)),
    );
  });

  test('collectUpcomingEventReminders keeps nearest events only', () {
    final now = DateTime(2026, 6, 28, 12, 0);
    final events = List.generate(
      70,
      (index) => _event(
        id: 'e$index',
        start: now.add(Duration(hours: index + 1)),
        reminderMinutesBefore: 15,
      ),
    );

    final candidates = collectUpcomingEventReminders(
      now: now,
      events: events,
      maxCount: 64,
    );

    expect(candidates, hasLength(64));
    expect(candidates.first.event.id, 'e0');
    expect(candidates.last.event.id, 'e63');
  });
}
