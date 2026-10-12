import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';

AppEvent _event(int day) {
  final start = DateTime(2026, 6, day, 10);
  return AppEvent(
    id: 'e-$day',
    dateTimeRange: DateTimeRange(
      start: start,
      end: start.add(const Duration(hours: 1)),
    ),
    title: 'Event $day',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.blue,
    checklist: const [],
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  test('indexEventsByDay groups events by date', () {
    final index = indexEventsByDay([_event(1), _event(1), _event(2)]);

    expect(eventsForDay(index, DateTime(2026, 6, 1)), hasLength(2));
    expect(eventsForDay(index, DateTime(2026, 6, 2)), hasLength(1));
    expect(eventsForDay(index, DateTime(2026, 6, 3)), isEmpty);
  });

  test('indexEventsByDay uses local calendar day for UTC timestamps', () {
    final utcStart = DateTime.utc(2026, 6, 1, 23);
    final local = utcStart.toLocal();
    final localDay = DateTime(local.year, local.month, local.day);
    final event = AppEvent(
      id: 'utc-late',
      dateTimeRange: DateTimeRange(
        start: utcStart,
        end: utcStart.add(const Duration(hours: 1)),
      ),
      title: 'Late UTC',
      startTime: '23:00',
      endTime: '00:00',
      color: Colors.blue,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
    );

    final index = indexEventsByDay([event]);

    expect(eventsForDay(index, localDay), hasLength(1));
    expect(eventsForDay(index, localDay).first.id, 'utc-late');
    expect(calendarDayKey(utcStart), localDay);
  });

  test('indexEventsByDay spans multi-day events across calendar days', () {
    final start = DateTime(2026, 6, 10, 22);
    final end = DateTime(2026, 6, 12, 10);
    final event = AppEvent(
      id: 'multi',
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: 'Conference',
      startTime: '22:00',
      endTime: '10:00',
      color: Colors.blue,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
    );

    final index = indexEventsByDay([event]);

    expect(eventsForDay(index, DateTime(2026, 6, 10)), hasLength(1));
    expect(eventsForDay(index, DateTime(2026, 6, 11)), hasLength(1));
    expect(eventsForDay(index, DateTime(2026, 6, 12)), hasLength(1));
    expect(eventsForDay(index, DateTime(2026, 6, 9)), isEmpty);
    expect(eventsForDay(index, DateTime(2026, 6, 13)), isEmpty);
  });

  test('EventDayIndexCache reuses the map for the same list instance', () {
    final events = [_event(1), _event(2)];
    final cache = EventDayIndexCache();
    final first = cache.of(events);
    expect(identical(cache.of(events), first), isTrue);
    expect(identical(cache.of([_event(1)]), first), isFalse);
  });

  test('WeekLoadWindow matches carousel length around the selected week', () {
    final selected = DateTime(2026, 6, 17);
    final start = WeekLoadWindow.rangeStart(selected);
    final end = WeekLoadWindow.rangeEnd(selected);
    expect(start.weekday, DateTime.monday);
    expect(
      end.difference(start).inDays,
      7 * (WeekLoadWindow.weeksBehind + 1 + WeekLoadWindow.weeksAhead),
    );
    expect(!selected.isBefore(start) && selected.isBefore(end), isTrue);
  });
}
