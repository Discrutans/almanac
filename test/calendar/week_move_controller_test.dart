import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_move_controller.dart';
import 'package:almanac/calendar/widgets/week/week_move_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _timed({
  String id = 'e1',
  DateTime? start,
  DateTime? end,
}) {
  final s = start ?? DateTime(2026, 9, 14, 10);
  final e = end ?? DateTime(2026, 9, 14, 11);
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(start: s, end: e),
    title: id,
    startTime: '${s.hour.toString().padLeft(2, '0')}:00',
    endTime: '${e.hour.toString().padLeft(2, '0')}:00',
    color: Colors.teal,
  );
}

WeekMoveCandidate _candidate(AppEvent event) {
  return WeekMoveCandidate(
    payload: WeekMoveEventPayload(event),
    delay: Duration.zero,
  );
}

void main() {
  test('start then pointerMove builds preview; commit uses last pointer', () {
    WeekDropTarget? Function(Offset)? resolver;
    final move = WeekMoveController(resolveTarget: (g) => resolver!(g));

    final event = _timed();
    final monday10 = WeekDropTarget(
      date: DateTime(2026, 9, 14),
      columnIndex: 0,
      columnCount: 3,
      minutesOfDay: 10 * 60,
    );
    final tuesday1430 = WeekDropTarget(
      date: DateTime(2026, 9, 15),
      columnIndex: 1,
      columnCount: 3,
      minutesOfDay: 14 * 60 + 30,
    );

    resolver = (_) => monday10;
    move.start(_candidate(event), global: const Offset(10, 20));
    expect(move.draggingEvent?.id, event.id);
    expect(move.preview, isNotNull);
    expect(move.preview!.startMinutes, 10 * 60);

    resolver = (_) => tuesday1430;
    move.pointerMove(const Offset(200, 80));
    expect(move.preview!.isOnDate(DateTime(2026, 9, 15)), isTrue);
    expect(move.preview!.startMinutes, 14 * 60 + 30);

    final result = move.commit();
    expect(result, isA<WeekMoveEventMoved>());
    final moved = result as WeekMoveEventMoved;
    expect(moved.date, DateTime(2026, 9, 15));
    expect(moved.startTime, const TimeOfDay(hour: 14, minute: 30));

    move.finish();
    expect(move.active, isFalse);
  });

  test('commit when inactive is cancelled', () {
    final move = WeekMoveController(resolveTarget: (_) => null);
    expect(move.commit(), isA<WeekMoveCancelled>());
  });

  test('unchanged when dropping on same timed slot', () {
    final event = _timed();
    final day = DateTime(2026, 9, 14);
    final move = WeekMoveController(
      resolveTarget: (_) => WeekDropTarget(
        date: day,
        columnIndex: 0,
        columnCount: 1,
        minutesOfDay: 10 * 60,
      ),
    );
    move.start(_candidate(event), global: Offset.zero);
    move.pointerMove(Offset.zero);
    expect(move.commit(), isA<WeekMoveUnchanged>());
  });

  test('offer and takeCandidate are one-shot', () {
    final move = WeekMoveController(resolveTarget: (_) => null);
    final event = _timed();
    move.offer(
      pointer: 1,
      global: Offset.zero,
      candidate: _candidate(event),
    );
    expect(move.takeCandidate(1)?.payload, isA<WeekMoveEventPayload>());
    expect(move.takeCandidate(1), isNull);
  });

  test('grab offset preserves relative position within event', () {
    final event = _timed();
    WeekDropTarget? Function(Offset)? resolver;
    final move = WeekMoveController(
      resolveTarget: (g) => resolver!(g),
    );

    resolver = (_) => WeekDropTarget(
      date: DateTime(2026, 9, 14),
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 10 * 60 + 30,
    );
    move.start(_candidate(event), global: const Offset(0, 50));

    resolver = (_) => WeekDropTarget(
      date: DateTime(2026, 9, 15),
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 11 * 60 + 30,
    );
    move.pointerMove(const Offset(0, 100));
    expect(move.preview!.isOnDate(DateTime(2026, 9, 15)), isTrue);
    expect(move.preview!.startMinutes, 11 * 60);
  });
}
