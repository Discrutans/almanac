import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_layout.dart';
import 'package:almanac/calendar/widgets/week/week_pinch_hour_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('weekHourHeightForZoom', () {
    test('levels are strip multiples', () {
      const strip = 46.0;
      expect(weekHourHeightForZoom(strip, 1), strip);
      expect(weekHourHeightForZoom(strip, 2), strip * 2);
    });

    test('clamps level', () {
      const strip = 40.0;
      expect(weekHourHeightForZoom(strip, 0), strip);
      expect(weekHourHeightForZoom(strip, 9), strip * 2);
    });
  });

  group('weekHourZoomLevelNearest', () {
    test('picks nearest of 1/2', () {
      const strip = 50.0;
      expect(weekHourZoomLevelNearest(strip, 50), 1);
      expect(weekHourZoomLevelNearest(strip, 100), 2);
      expect(weekHourZoomLevelNearest(strip, 150), 2);
      expect(weekHourZoomLevelNearest(strip, 74), 1);
      expect(weekHourZoomLevelNearest(strip, 76), 2);
    });
  });

  group('WeekTimedPlacement.visibleTextWidthPx', () {
    test('cascade column text strip is narrower than fill', () {
      final placement = WeekTimedPlacement(
        event: AppEvent(
          id: 'a',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 9, 10, 10),
            end: DateTime(2026, 9, 10, 11),
          ),
          title: 'A',
          startTime: '10:00',
          endTime: '11:00',
          color: Colors.blue,
        ),
        startMinutes: 10 * 60,
        endMinutes: 11 * 60,
        columnIndex: 0,
        columnCount: 3,
      );
      const dayWidth = 100.0;
      final fill = placement.widthPx(dayWidth);
      final text = placement.visibleTextWidthPx(dayWidth);
      expect(text, lessThan(fill));
      expect(text, greaterThan(0));
    });
  });

  group('WeekPinchHourController', () {
    test('snaps to nearest level on pinch end', () {
      final controller = WeekPinchHourController(
        zoomLevel: 1,
        stripHeight: 50,
      );
      expect(controller.hourHeight, 50);

      controller.handlePointerDown(
        const PointerDownEvent(pointer: 1, position: Offset(0, 0)),
      );
      controller.handlePointerDown(
        const PointerDownEvent(pointer: 2, position: Offset(100, 0)),
      );
      controller.handlePointerMove(
        const PointerMoveEvent(pointer: 2, position: Offset(220, 0)),
      );
      expect(controller.hourHeight, greaterThan(50));

      final result = controller.handlePointerUp(
        const PointerUpEvent(pointer: 2, position: Offset(220, 0)),
      );
      expect(result.snappedLevel, isNotNull);
      expect(controller.zoomLevel, inInclusiveRange(1, 2));
      expect(
        controller.hourHeight,
        weekHourHeightForZoom(50, controller.zoomLevel),
      );
    });
  });
}
