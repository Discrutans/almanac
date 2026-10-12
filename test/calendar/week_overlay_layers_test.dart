import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/widgets/week/week_event_cell_contour.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_layout.dart';
import 'package:almanac/data/events/event_overlap.dart';
import 'package:almanac/data/local/local_data_codec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _shift({
  required String id,
  required DateTime day,
  required String start,
  required String end,
}) {
  final sp = start.split(':');
  final ep = end.split(':');
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(sp[0]),
        int.parse(sp[1]),
      ),
      end: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(ep[0]),
        int.parse(ep[1]),
      ),
    ),
    title: 'Смена',
    startTime: start,
    endTime: end,
    color: Colors.blue,
    seriesId: 'schedule-1',
    explicitEntrySource: CalendarEntrySource.scheduleGenerated,
  );
}

AppEvent _personal({
  required String id,
  required DateTime day,
  required String start,
  required String end,
  String? parentEventId,
}) {
  final sp = start.split(':');
  final ep = end.split(':');
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(sp[0]),
        int.parse(sp[1]),
      ),
      end: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(ep[0]),
        int.parse(ep[1]),
      ),
    ),
    title: id,
    startTime: start,
    endTime: end,
    color: Colors.teal,
    parentEventId: parentEventId,
  );
}

void main() {
  final day = DateTime(2026, 9, 16);

  test('create snap is hour floor; resize snap stays 15', () {
    expect(weekHourFloorMinutes(6 * 60 + 40), 6 * 60);
    expect(weekHourFloorMinutes(6 * 60 + 20), 6 * 60);
    expect(snapWeekByKind(6 * 60 + 40, WeekMinuteSnapKind.hourCell), 6 * 60);
    expect(snapWeekMinutes(6 * 60 + 40), 6 * 60 + 45);
    expect(snapWeekMinutes(6 * 60 + 22), 6 * 60 + 15);
  });

  test('fromTap builds a full hour slot from hour floor', () {
    final slot = WeekGridSlot.fromTap(
      day,
      const TimeOfDay(hour: 6, minute: 40),
    );
    expect(slot.startMinutes, 6 * 60);
    expect(slot.endMinutes, 7 * 60);
  });

  test('empty shift occupies only boundary hours', () {
    final shift = _shift(id: 's1', day: day, start: '08:00', end: '17:00');
    final occupied = occupiedHourSlots([shift]);
    expect(occupied, {8, 16});
    final visible = visibleHourSlots(
      occupied,
      paddingBefore: 1,
      paddingAfter: 1,
    );
    expect(visible.contains(8), isTrue);
    expect(visible.contains(16), isTrue);
    expect(visible.contains(12), isFalse);
  });

  test('shift with nested child expands full shift span', () {
    final shift = _shift(id: 's1', day: day, start: '08:00', end: '17:00');
    final child = _personal(
      id: 'c1',
      day: day,
      start: '16:00',
      end: '17:15',
      parentEventId: 's1',
    );
    final occupied = occupiedHourSlots([shift, child]);
    // Nested tasks force the parent shift to keep every hour visible.
    expect(occupied.contains(8), isTrue);
    expect(occupied.contains(9), isTrue);
    expect(occupied.contains(16), isTrue);
  });

  test('personal does not conflict with schedule shift', () {
    final shift = _shift(id: 's1', day: day, start: '08:00', end: '17:00');
    final conflict = hasEventConflict(
      candidateStart: DateTime(2026, 9, 16, 16),
      candidateEnd: DateTime(2026, 9, 16, 17, 15),
      existingEvents: [shift],
    );
    expect(conflict, isFalse);
  });

  test('resolveParentShiftEvent prefers shift containing start', () {
    final shift = _shift(id: 's1', day: day, start: '08:00', end: '17:00');
    final parent = resolveParentShiftEvent(
      startMinutes: 16 * 60,
      endMinutes: 17 * 60 + 15,
      dayEvents: [shift],
    );
    expect(parent?.id, 's1');
  });

  test('pack puts shifts under personal columns', () {
    final shift = _shift(id: 's1', day: day, start: '08:00', end: '17:00');
    final child = _personal(id: 'c1', day: day, start: '16:00', end: '17:00');
    final packed = packWeekTimedEvents([shift, child]);
    expect(packed.first.event.id, 's1');
    expect(packed.first.columnIndex, 0);
    expect(packed.last.event.id, 'c1');
  });

  test('bottom-align pad helpers stay consistent', () {
    expect(weekTimedBottomAlignPad(axisHeight: 400, viewportHeight: 500), 100);
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final pad = weekTimedBottomAlignPad(
      axisHeight: axis.totalHeight,
      viewportHeight: 2000,
    );
    expect(
      weekTimedMinutesForContentY(
        axis: axis,
        contentY: pad,
        viewportHeight: 2000,
      ),
      0,
    );
  });

  test('LocalDataCodec roundtrips parentEventId', () {
    final child = _personal(
      id: 'c1',
      day: day,
      start: '16:00',
      end: '17:00',
      parentEventId: 'shift-1',
    );
    final json = LocalDataSnapshot(
      profiles: const [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {
        'default': [child],
      },
      schedulesByProfile: const {},
      templatesByProfile: const {},
      requestsByProfile: const {},
    ).toJson();
    final restored = LocalDataSnapshot.fromJson(
      json,
    ).eventsByProfile['default']!.single;
    expect(restored.parentEventId, 'shift-1');
  });

  test('visibleHourSlots padding before/after is asymmetric', () {
    expect(
      visibleHourSlots({7}, paddingBefore: 2, paddingAfter: 0),
      {5, 6, 7},
    );
    expect(
      visibleHourSlots({7}, paddingBefore: 0, paddingAfter: 2),
      {7, 8, 9},
    );
  });

  test('LocalDataCodec roundtrips week hour padding', () {
    final json = const LocalDataSnapshot(
      profiles: [],
      activeProfileId: 'default',
      visibleProfileIds: {'default'},
      eventsByProfile: {},
      schedulesByProfile: {},
      templatesByProfile: {},
      requestsByProfile: {},
      weekHourPaddingBefore: 3,
      weekHourPaddingAfter: 0,
    ).toJson();
    final restored = LocalDataSnapshot.fromJson(json);
    expect(restored.weekHourPaddingBefore, 3);
    expect(restored.weekHourPaddingAfter, 0);
  });

  test('event fill clips to 15 minutes inside an hour cell', () {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final hour = axis.segments.firstWhere((s) => s.isHour && s.hour == 10);
    final full = weekEventFillRectInSegment(
      segment: hour,
      width: 100,
      originY: 0,
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
    )!;
    final quarter = weekEventFillRectInSegment(
      segment: hour,
      width: 100,
      originY: 0,
      startMinutes: 10 * 60,
      endMinutes: 10 * 60 + 15,
    )!;
    expect(quarter.height, closeTo(full.height / 4, 0.5));
    expect(quarter.top, closeTo(full.top, 0.5));
    expect(quarter.left, full.left);
    expect(quarter.right, full.right);
  });

  test('hour cells are square insets matching column width', () {
    // ignore: deprecated_member_use_from_same_package
    expect(weekSquareHourHeight(110), 110);
    // ignore: deprecated_member_use_from_same_package
    expect(weekSquareHourHeight(20), kWeekHourHeightMin);
    // ignore: deprecated_member_use_from_same_package
    expect(weekSquareHourHeight(400), kWeekHourHeightMax);

    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 110,
    );
    final hour10 = axis.segments.firstWhere((s) => s.isHour && s.hour == 10);
    final hour11 = axis.segments.firstWhere((s) => s.isHour && s.hour == 11);
    final a = weekHourCellRect(segment: hour10, width: 110);
    final b = weekHourCellRect(segment: hour11, width: 110);
    expect(a.left, kWeekHourCellInset);
    expect(a.width, closeTo(110 - 2 * kWeekHourCellInset, 0.01));
    expect(a.height, closeTo(110 - 2 * kWeekHourCellInset, 0.01));
    expect(a.width, closeTo(a.height, 0.01));
    expect(kWeekHourCellRadius, 8);
    expect(b.top - a.bottom, closeTo(2 * kWeekHourCellInset, 0.01));
  });
}
