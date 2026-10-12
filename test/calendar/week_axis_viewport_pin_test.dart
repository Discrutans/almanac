import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_axis_viewport_pin.dart';
import 'package:almanac/calendar/widgets/week/week_event_cell_contour.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _timed({
  required String id,
  required int startHour,
  int durationHours = 1,
}) {
  final start = DateTime(2026, 9, 19, startHour);
  final end = start.add(Duration(hours: durationHours));
  return AppEvent(
    id: id,
    title: id,
    dateTimeRange: DateTimeRange(start: start, end: end),
    startTime: '${startHour.toString().padLeft(2, '0')}:00',
    endTime:
        '${(startHour + durationHours).toString().padLeft(2, '0')}:00',
    color: Colors.teal,
  );
}

void main() {
  group('WeekAxisViewportPin', () {
    test('capture → expand keeps same viewportY for pin minutes', () {
      final collapsed = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 14)],
        hideEmptyHours: true,
        expanded: false,
        hourHeight: 60,
        paddingBefore: 1,
        paddingAfter: 1,
      );
      const scroll = 40.0;
      const pinMinutes = 14 * 60;
      final pin = WeekAxisViewportPin.capture(
        axis: collapsed,
        scrollOffset: scroll,
        pinMinutes: pinMinutes,
        bottomAlignPad: 10,
        topDockHeight: 20,
      );
      expect(pin.pinMinutes, pinMinutes);

      final expanded = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 14)],
        hideEmptyHours: true,
        expanded: true,
        hourHeight: 60,
      );
      final newOffset = pin.scrollOffsetFor(
        newAxis: expanded,
        maxScrollExtent: 2000,
        bottomAlignPad: 0,
        topDockHeight: 20,
      );
      final restoredY = weekAxisViewportY(
        axis: expanded,
        pinMinutes: pinMinutes,
        scrollOffset: newOffset,
        bottomAlignPad: 0,
        topDockHeight: 20,
      );
      expect(restoredY, closeTo(pin.viewportY, 0.75));
    });

    test('expand → collapse restores viewportY', () {
      final expanded = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 10)],
        hideEmptyHours: true,
        expanded: true,
        hourHeight: 50,
      );
      // Pin near the top of the viewport so collapse can still keep it.
      final pin = WeekAxisViewportPin.capture(
        axis: expanded,
        scrollOffset: expanded.yForMinutes(10 * 60) - 40,
        pinMinutes: 10 * 60,
      );
      expect(pin.viewportY, closeTo(40, 1));
      final collapsed = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 10)],
        hideEmptyHours: true,
        expanded: false,
        hourHeight: 50,
        paddingBefore: 2,
        paddingAfter: 1,
      );
      final offset = pin.scrollOffsetFor(
        newAxis: collapsed,
        maxScrollExtent: 5000,
      );
      final y = weekAxisViewportY(
        axis: collapsed,
        pinMinutes: pin.pinMinutes,
        scrollOffset: offset,
      );
      expect(y, closeTo(pin.viewportY, 0.75));
    });

    test('retargetMinutes keeps viewportY', () {
      final axis = WeekHourAxis.fromEvents(
        events: const [],
        hideEmptyHours: false,
        expanded: true,
        hourHeight: 60,
      );
      final pin = WeekAxisViewportPin.capture(
        axis: axis,
        scrollOffset: 80,
        pinMinutes: 12 * 60,
      );
      final moved = pin.retargetMinutes(18 * 60);
      expect(moved.viewportY, pin.viewportY);
      expect(moved.pinMinutes, 18 * 60);
    });

    test('bottomAlignPad and topDock affect capture', () {
      final axis = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 16)],
        hideEmptyHours: true,
        expanded: false,
        hourHeight: 60,
      );
      final plain = WeekAxisViewportPin.capture(
        axis: axis,
        scrollOffset: 0,
        pinMinutes: 16 * 60,
      );
      final padded = WeekAxisViewportPin.capture(
        axis: axis,
        scrollOffset: 0,
        pinMinutes: 16 * 60,
        bottomAlignPad: 40,
        topDockHeight: 30,
      );
      expect(padded.viewportY, closeTo(plain.viewportY + 70, 0.01));
    });
  });

  group('weekEventFillPieces borders', () {
    test('multi-hour interval yields per-cell pieces with cell radii', () {
      final axis = WeekHourAxis.fromEvents(
        events: const [],
        hideEmptyHours: false,
        expanded: true,
        hourHeight: 100,
      );
      final pieces = weekEventFillPieces(
        axis: axis,
        width: 100,
        originY: 0,
        startMinutes: 10 * 60,
        endMinutes: 12 * 60,
      );
      expect(pieces.length, greaterThanOrEqualTo(2));
      for (final piece in pieces) {
        final rrect = weekEventFillRRect(
          fill: piece.fill,
          cell: piece.cell,
          radius: kWeekHourCellRadius,
        );
        // Full-hour pieces round all corners like empty grid cells.
        if ((piece.fill.top - piece.cell.top).abs() <= 0.75 &&
            (piece.fill.bottom - piece.cell.bottom).abs() <= 0.75) {
          expect(rrect.tlRadiusX, kWeekHourCellRadius);
          expect(rrect.trRadiusX, kWeekHourCellRadius);
          expect(rrect.blRadiusX, kWeekHourCellRadius);
          expect(rrect.brRadiusX, kWeekHourCellRadius);
        }
      }
    });

    test('empty pieces list is empty', () {
      expect(
        weekEventFillPieces(
          axis: const WeekHourAxis(segments: []),
          width: 100,
          originY: 0,
          startMinutes: 0,
          endMinutes: 60,
        ),
        isEmpty,
      );
    });
  });

  group('weekNowLineY', () {
    test('returns y on visible hour', () {
      final axis = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 14)],
        hideEmptyHours: true,
        expanded: false,
        hourHeight: 60,
        paddingBefore: 0,
        paddingAfter: 0,
      );
      expect(weekNowLineY(axis, 14 * 60 + 30), isNotNull);
    });

    test('returns null inside collapsed gutter', () {
      final axis = WeekHourAxis.fromEvents(
        events: [_timed(id: 'a', startHour: 8), _timed(id: 'b', startHour: 20)],
        hideEmptyHours: true,
        expanded: false,
        hourHeight: 60,
        paddingBefore: 0,
        paddingAfter: 0,
      );
      // Midday should be in a gutter between morning and evening clusters.
      expect(weekNowLineY(axis, 12 * 60), isNull);
    });
  });
}
