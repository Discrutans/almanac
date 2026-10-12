import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_hour_layout.dart';
import 'package:almanac/data/events/event_overlap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _timed({
  required String id,
  required String start,
  required String end,
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
  );
}

void main() {
  test('abutting timed events share one pack column and are not a conflict', () {
    final first = _timed(id: 'a', start: '10:00', end: '11:00');
    final second = _timed(id: 'b', start: '11:00', end: '12:00');

    expect(
      hasEventConflict(
        candidateStart: second.start,
        candidateEnd: second.end,
        existingEvents: [first],
      ),
      isFalse,
    );

    final packed = packWeekTimedEvents([first, second]);
    expect(packed, hasLength(2));
    expect(packed.every((p) => p.columnIndex == 0), isTrue);
    expect(packed.every((p) => p.columnCount == 1), isTrue);
  });

  test('overlapping timed events pack into two columns', () {
    final first = _timed(id: 'a', start: '10:00', end: '11:30');
    final second = _timed(id: 'b', start: '11:00', end: '12:00');

    expect(
      hasEventConflict(
        candidateStart: second.start,
        candidateEnd: second.end,
        existingEvents: [first],
      ),
      isTrue,
    );

    final packed = packWeekTimedEvents([first, second]);
    expect(packed, hasLength(2));
    expect(packed.map((p) => p.columnCount).toSet(), {2});
    expect(packed.map((p) => p.columnIndex).toSet(), {0, 1});
  });
}
