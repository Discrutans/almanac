import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drag_policy.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_move_controller.dart';
import 'package:almanac/calendar/widgets/week/week_move_scope.dart';
import 'package:almanac/calendar/widgets/week/week_move_types.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:almanac/calendar/widgets/week/week_ui_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event() {
  return AppEvent(
    id: 'armed-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 8, 10),
      end: DateTime(2026, 9, 8, 11),
    ),
    title: 'Armed',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.teal,
  );
}

void main() {
  testWidgets('armed selection frame body offers move candidate', (
    tester,
  ) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 48,
    );
    final event = _event();
    final move = WeekMoveController(resolveTarget: (_) => null);
    addTearDown(move.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekMoveScope(
            controller: move,
            child: SizedBox(
              height: axis.totalHeight,
              width: 200,
              child: WeekSelectionFrame(
                axis: axis,
                startMinutes: 10 * 60,
                endMinutes: 11 * 60,
                color: Colors.teal,
                fillAlpha: WeekUiTokens.armedFillAlpha,
                dragEvent: event,
                onBodyPointerDown: (e) {
                  move.offer(
                    pointer: e.pointer,
                    global: e.position,
                    candidate: WeekMoveCandidate(
                      payload: WeekMoveEventPayload(event),
                      delay: weekDragDelayArmed,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(WeekSelectionFrame.bodyDragKey), findsOneWidget);
    expect(find.byType(LongPressDraggable), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(WeekSelectionFrame.bodyDragKey)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(move.hasPendingCandidate, isTrue);
    await gesture.up();
  });

  testWidgets('slot body offers WeekGridSlot candidate', (tester) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 48,
    );
    final slot = WeekGridSlot(
      date: DateTime(2026, 9, 8),
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
    );
    final move = WeekMoveController(resolveTarget: (_) => null);
    addTearDown(move.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekMoveScope(
            controller: move,
            child: SizedBox(
              height: axis.totalHeight,
              width: 200,
              child: WeekSelectionFrame(
                axis: axis,
                startMinutes: slot.startMinutes,
                endMinutes: slot.endMinutes,
                color: Colors.teal,
                dragSlot: slot,
                onBodyPointerDown: (e) {
                  move.offer(
                    pointer: e.pointer,
                    global: e.position,
                    candidate: WeekMoveCandidate(
                      payload: WeekMoveSlotPayload(slot),
                      delay: weekDragHoldImmediate,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(WeekSelectionFrame.bodyDragKey), findsOneWidget);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(WeekSelectionFrame.bodyDragKey)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(move.hasPendingCandidate, isTrue);
    await gesture.up();
  });
}
