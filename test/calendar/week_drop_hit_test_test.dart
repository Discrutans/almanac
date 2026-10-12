import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'timed-box hit-test with headerHeight 0 is not shifted by the date strip',
    () {
      const stripHeight = 48.0;
      const hourHeight = 48.0;
      const columnWidth = 100.0;
      final dates = [
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 16),
      ];
      final axis = WeekHourAxis.fromEvents(
        events: const [],
        hideEmptyHours: false,
        expanded: true,
        hourHeight: hourHeight,
      );
      final timedBox = _FakeViewportBox(
        size: Size(columnWidth * dates.length, 400),
        globalOrigin: const Offset(0, stripHeight),
      );
      final unifiedBox = _FakeViewportBox(
        size: Size(columnWidth * dates.length, 400 + stripHeight),
        globalOrigin: Offset.zero,
      );
      // Two hours into the timed canvas (plus a few px so snap stays in hour 2).
      final global = Offset(20, stripHeight + 2 * hourHeight + 4);

      final timed = weekDropTargetAt(
        globalPosition: global,
        viewportBox: timedBox,
        columnWidth: columnWidth,
        dayDates: dates,
        axis: axis,
        headerHeight: 0,
      );
      final wronglyUnifiedAsTimed = weekDropTargetAt(
        globalPosition: global,
        viewportBox: unifiedBox,
        columnWidth: columnWidth,
        dayDates: dates,
        axis: axis,
        headerHeight: 0,
      );

      expect(timed, isNotNull);
      expect(timed!.minutesOfDay! ~/ 60, 2);
      expect(wronglyUnifiedAsTimed, isNotNull);
      expect(wronglyUnifiedAsTimed!.minutesOfDay! ~/ 60, isNot(2));
    },
  );

  test('weekDropTargetAt maps columns and snapped minutes', () {
    final dates = [
      DateTime(2026, 9, 14),
      DateTime(2026, 9, 15),
      DateTime(2026, 9, 16),
    ];
    const columnWidth = 100.0;
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 60,
    );
    final viewport = _FakeViewportBox(
      size: Size(columnWidth * dates.length, 400),
      globalOrigin: const Offset(50, 100),
    );

    // Second column, near top of hour 2 (y ≈ 120 with scroll 0).
    final target = weekDropTargetAt(
      globalPosition: Offset(50 + columnWidth + 20, 100 + 125),
      viewportBox: viewport,
      columnWidth: columnWidth,
      dayDates: dates,
      axis: axis,
    );
    expect(target, isNotNull);
    expect(target!.date, DateTime(2026, 9, 15));
    expect(target.ghost, isFalse);
    expect(target.minutesOfDay, isNotNull);
    expect(target.minutesOfDay! ~/ 60, 2);
  });

  test('weekResolveDropCommit rejects same-day all-day no-op', () {
    final day = DateTime(2026, 9, 15);
    final event = AppEvent(
      id: 'note',
      dateTimeRange: DateTimeRange(
        start: DateTime(day.year, day.month, day.day),
        end: DateTime(day.year, day.month, day.day, 23, 59),
      ),
      title: 'Note',
      startTime: '',
      endTime: '',
      color: Colors.amber,
      kind: CalendarEntryKind.note,
    );
    final target = WeekDropTarget(
      date: day,
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 600,
      isAllDayHost: true,
    );
    final resolved = weekResolveDropCommit(event: event, target: target);
    expect(resolved.accepted, isFalse);
  });

  test('weekResolveDropCommit accepts drop onto a busy timed slot', () {
    final day = DateTime(2026, 9, 15);
    final moving = AppEvent(
      id: 'moving',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 15, 10),
        end: DateTime(2026, 9, 15, 11),
      ),
      title: 'Moving',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
    );
    final target = WeekDropTarget(
      date: day,
      columnIndex: 0,
      columnCount: 1,
      minutesOfDay: 14 * 60,
      isAllDayHost: false,
    );
    final resolved = weekResolveDropCommit(event: moving, target: target);
    expect(resolved.accepted, isTrue);
    expect(resolved.startTime, const TimeOfDay(hour: 14, minute: 0));
  });

  test('weekAxisKeepVisibleOffset preserves pin across height change', () {
    final small = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 48,
    );
    final large = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 96,
    );
    const pin = 10 * 60;
    const viewportY = 80.0;
    final offset = weekAxisKeepVisibleOffset(
      newAxis: large,
      pinMinutes: pin,
      viewportY: viewportY,
      maxScrollExtent: large.totalHeight,
    );
    final restoredY = weekAxisViewportY(
      axis: large,
      pinMinutes: pin,
      scrollOffset: offset,
    );
    expect(restoredY, closeTo(viewportY, 1.0));
    expect(small.hourHeight, lessThan(large.hourHeight));
  });

  test('ghost lane still builds drop preview for timed drag', () {
    final day = DateTime(2026, 9, 21);
    final event = AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 19, 10),
        end: DateTime(2026, 9, 19, 11),
      ),
      title: 'e1',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
    );
    final target = WeekDropTarget(
      date: day,
      columnIndex: 3,
      columnCount: 7,
      ghost: true,
      minutesOfDay: 14 * 60,
    );
    final preview = weekDropPreviewForTarget(target: target, dragging: event);
    expect(preview, isNotNull);
    expect(preview!.isOnDate(day), isTrue);
    expect(preview.startMinutes, 14 * 60);
  });

  test('drop preview follows day (X) and minutes (Y) target changes', () {
    final event = AppEvent(
      id: 'move-xy',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 14, 10),
        end: DateTime(2026, 9, 14, 11),
      ),
      title: 'move',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
    );
    final monday = weekDropPreviewForTarget(
      target: WeekDropTarget(
        date: DateTime(2026, 9, 14),
        columnIndex: 0,
        columnCount: 3,
        minutesOfDay: 10 * 60,
      ),
      dragging: event,
    );
    final tuesdayLater = weekDropPreviewForTarget(
      target: WeekDropTarget(
        date: DateTime(2026, 9, 15),
        columnIndex: 1,
        columnCount: 3,
        minutesOfDay: 14 * 60 + 30,
      ),
      dragging: event,
    );
    expect(monday, isNotNull);
    expect(tuesdayLater, isNotNull);
    expect(monday!.isOnDate(DateTime(2026, 9, 14)), isTrue);
    expect(monday.startMinutes, 10 * 60);
    expect(tuesdayLater!.isOnDate(DateTime(2026, 9, 15)), isTrue);
    expect(tuesdayLater.startMinutes, 14 * 60 + 30);
    expect(tuesdayLater.endMinutes - tuesdayLater.startMinutes, 60);
  });

  test('weekResolveDropCommit accepts ghost lane timed drop', () {
    final day = DateTime(2026, 9, 21);
    final event = AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 19, 10),
        end: DateTime(2026, 9, 19, 11),
      ),
      title: 'e1',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
    );
    final target = WeekDropTarget(
      date: day,
      columnIndex: 3,
      columnCount: 7,
      ghost: true,
      minutesOfDay: 16 * 60,
    );
    final resolved = weekResolveDropCommit(event: event, target: target);
    expect(resolved.accepted, isTrue);
    expect(resolved.date, day);
    expect(resolved.startTime?.hour, 16);
  });
}

class _FakeViewportBox extends RenderBox {
  _FakeViewportBox({required Size size, required this.globalOrigin}) {
    _size = size;
  }

  late Size _size;
  final Offset globalOrigin;

  @override
  Size get size => _size;

  @override
  Offset globalToLocal(Offset point, {RenderObject? ancestor}) {
    return point - globalOrigin;
  }
}
