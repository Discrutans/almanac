import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drag_policy.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_move_controller.dart';
import 'package:almanac/calendar/widgets/week/week_move_scope.dart';
import 'package:almanac/calendar/widgets/week/week_move_types.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:almanac/calendar/widgets/week/week_timed_drag_layer.dart';
import 'package:almanac/calendar/widgets/week/week_ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event() {
  return AppEvent(
    id: 'move-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 14, 10),
      end: DateTime(2026, 9, 14, 11),
    ),
    title: 'Move',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.teal,
  );
}

void main() {
  testWidgets('layer onResult commits after hold path start', (tester) async {
    final event = _event();
    WeekMoveResult? result;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    final move = WeekMoveController(
      resolveTarget: (_) => WeekDropTarget(
        date: DateTime(2026, 9, 15),
        columnIndex: 1,
        columnCount: 3,
        minutesOfDay: 14 * 60 + 30,
      ),
    );
    addTearDown(move.dispose);

    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 48,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 400,
            child: WeekTimedDragLayer(
              move: move,
              axis: axis,
              dates: [
                DateTime(2026, 9, 14),
                DateTime(2026, 9, 15),
                DateTime(2026, 9, 16),
              ],
              columnWidth: 100,
              timedScroll: scroll,
              allDayHeight: 0,
              onActiveChanged: (_, _) {},
              onDragPointer: (_) {},
              onResult: (r) => result = r,
              child: WeekMoveScope(
                controller: move,
                child: Listener(
                  onPointerDown: (e) {
                    move.offer(
                      pointer: e.pointer,
                      global: e.position,
                      candidate: WeekMoveCandidate(
                        payload: WeekMoveEventPayload(event),
                        delay: weekDragDelayImmediate,
                      ),
                    );
                  },
                  child: const ColoredBox(
                    key: ValueKey('harness-body'),
                    color: Colors.teal,
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('harness-body'))),
    );
    await tester.pump(weekDragDelayImmediate + const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(40, 60));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(result, isA<WeekMoveEventMoved>());
    expect(move.active, isFalse);
  });
}
