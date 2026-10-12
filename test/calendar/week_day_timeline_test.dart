// ignore_for_file: deprecated_member_use_from_same_package

import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_day_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _event({
  required String id,
  required DateTime day,
  required CalendarEntryKind kind,
  String start = '',
  String end = '',
}) {
  final range = kind == CalendarEntryKind.event
      ? DateTimeRange(
          start: DateTime(day.year, day.month, day.day, 10),
          end: DateTime(day.year, day.month, day.day, 12),
        )
      : AppEvent.dateOnlyRange(day);
  return AppEvent(
    id: id,
    dateTimeRange: range,
    title: id,
    startTime: start,
    endTime: end,
    color: Colors.teal,
    kind: kind,
  );
}

void main() {
  final tuesday = DateTime(2026, 9, 8);
  final wednesday = DateTime(2026, 9, 9);
  final thursday = DateTime(2026, 9, 10);

  test('same start times share one timed lane', () {
    final blueprint = buildWeekTimelineBlueprint([
      [
        _event(
          id: 'shift-tue',
          day: tuesday,
          kind: CalendarEntryKind.event,
          start: '08:00',
          end: '17:00',
        ),
      ],
      [
        _event(
          id: 'shift-wed',
          day: wednesday,
          kind: CalendarEntryKind.event,
          start: '08:00',
          end: '17:00',
        ),
      ],
    ]);

    expect(blueprint.timedLanes, hasLength(1));
    expect(blueprint.timedLanes.single.startMinutes, 8 * 60);
  });

  test('earlier start sits in a lane above later start', () {
    final blueprint = buildWeekTimelineBlueprint([
      [
        _event(
          id: 'day',
          day: tuesday,
          kind: CalendarEntryKind.event,
          start: '08:00',
          end: '17:00',
        ),
      ],
      [
        _event(
          id: 'early',
          day: thursday,
          kind: CalendarEntryKind.event,
          start: '03:17',
          end: '08:17',
        ),
        _event(
          id: 'day',
          day: thursday,
          kind: CalendarEntryKind.event,
          start: '08:00',
          end: '17:00',
        ),
      ],
    ]);

    expect(blueprint.timedLanes.map((lane) => lane.startMinutes).toList(), [
      3 * 60 + 17,
      8 * 60,
    ]);
  });

  test('notes and checklists sit in the all-day band above timed lanes', () {
    final blueprint = buildWeekTimelineBlueprint([
      [
        _event(id: 'note', day: tuesday, kind: CalendarEntryKind.note),
        _event(id: 'list', day: tuesday, kind: CalendarEntryKind.checklist),
        _event(
          id: 'shift',
          day: tuesday,
          kind: CalendarEntryKind.event,
          start: '08:00',
          end: '17:00',
        ),
      ],
    ]);

    expect(blueprint.allDayLanes.map((lane) => lane.kind).toList(), [
      CalendarEntryKind.checklist,
      CalendarEntryKind.note,
    ]);
    expect(
      blueprint.allDayLanes.where((lane) => lane.expands).single.kind,
      CalendarEntryKind.note,
    );
    expect(blueprint.timedLanes, hasLength(1));
  });

  test('column order is all-day kinds then start time', () {
    final day = DateTime(2026, 9, 8);
    final ordered = sortWeekColumnEvents([
      _event(
        id: 'late',
        day: day,
        kind: CalendarEntryKind.event,
        start: '10:00',
        end: '12:00',
      ),
      _event(id: 'note', day: day, kind: CalendarEntryKind.note),
      _event(
        id: 'early',
        day: day,
        kind: CalendarEntryKind.event,
        start: '08:00',
        end: '17:00',
      ),
      _event(id: 'list', day: day, kind: CalendarEntryKind.checklist),
    ]);

    expect(ordered.map((event) => event.id).toList(), [
      'list',
      'note',
      'early',
      'late',
    ]);
  });
}
