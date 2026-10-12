import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_move_controller.dart';
import 'package:almanac/calendar/widgets/week/week_move_types.dart';
import 'package:almanac/calendar/widgets/week/week_timed_drag_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event() {
  return AppEvent(
    id: 'geom-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 14, 10),
      end: DateTime(2026, 9, 14, 11),
    ),
    title: 'Geom',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.teal,
  );
}

void main() {
  testWidgets('preview overlay column is full axis height (single Y placement)', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);

    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 48,
    );
    const colWidth = 120.0;

    WeekDropTarget? Function(Offset)? resolver;
    final move = WeekMoveController(
      resolveTarget: (g) => resolver!(g),
    );
    addTearDown(move.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: colWidth,
            height: 400,
            child: WeekTimedDragLayer(
              move: move,
              axis: axis,
              dates: [DateTime(2026, 9, 14)],
              columnWidth: colWidth,
              timedScroll: scroll,
              allDayHeight: 24,
              onActiveChanged: (_, _) {},
              onDragPointer: (_) {},
              onResult: (_) {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    resolver = (_) => WeekDropTarget(
      date: DateTime(2026, 9, 14),
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 10 * 60,
    );
    move.start(
      WeekMoveCandidate(
        payload: WeekMoveEventPayload(_event()),
        delay: Duration.zero,
      ),
      global: const Offset(1, 1),
    );
    resolver = (_) => WeekDropTarget(
      date: DateTime(2026, 9, 14),
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 10 * 60 + 30,
    );
    move.pointerMove(const Offset(2, 2));
    await tester.pump();

    expect(move.preview!.startMinutes, 10 * 60 + 30);
    final frameBox = tester.renderObject<RenderBox>(
      find.byKey(WeekDropPreview.previewKey),
    );
    expect(frameBox.size.height, axis.totalHeight);
  });
}
