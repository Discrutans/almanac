import 'package:almanac/calendar/widgets/week/week_drag_policy.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection frame drag body is not full-column when range is valid', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: axis.totalHeight,
            width: 200,
            child: WeekSelectionFrame(
              axis: axis,
              startMinutes: slot.startMinutes,
              endMinutes: slot.endMinutes,
              color: Colors.teal,
              dragSlot: slot,
              onBodyPointerDown: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = tester.getSize(find.byKey(WeekSelectionFrame.bodyDragKey));
    expect(body.height, lessThan(axis.totalHeight * 0.2));
    expect(body.height, greaterThanOrEqualTo(kWeekHourMinEventHeight));
  });
}
