import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _timed({
  required String id,
  required DateTime day,
  required String start,
  required String end,
}) {
  final startParts = start.split(':');
  final endParts = end.split(':');
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: DateTime(
        day.year,
        day.month,
        day.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      ),
      end: DateTime(
        day.year,
        day.month,
        day.day,
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
  final day = DateTime(2026, 9, 8);

  // ignore: deprecated_member_use_from_same_package
  test('hour cells are tall enough for a finger', () {
    expect(kWeekHourHeight, greaterThanOrEqualTo(48));
    // ignore: deprecated_member_use_from_same_package
    expect(weekSquareHourHeight(110), 110);
  });

  test('all-day uses axis padding hours, not a separate dock', () {
    // ignore: deprecated_member_use_from_same_package
    expect(weekAllDayBandHeightForCounts(0), 0);
    // ignore: deprecated_member_use_from_same_package
    expect(weekAllDayBandHeightForCounts(1, hourHeight: 100), 0);
    // ignore: deprecated_member_use_from_same_package
    expect(weekAllDayBandHeightForCounts(5, hourHeight: 100), 0);
  });

  test('weekAllDayReserveHours grows with chip count', () {
    expect(weekAllDayReserveHours(0), 0);
    expect(weekAllDayReserveHours(1, hourHeight: 72), 1);
    expect(
      weekAllDayReserveHours(5, hourHeight: 48),
      greaterThan(weekAllDayReserveHours(1, hourHeight: 48)),
    );
  });

  test('weekAllDayHostSegments falls back when axis is full', () {
    final day = DateTime(2026, 9, 8);
    final events = [
      for (var hour = 0; hour < 24; hour++)
        _timed(
          id: 'h$hour',
          day: day,
          start: '${hour.toString().padLeft(2, '0')}:00',
          end: hour == 23
              ? '23:59'
              : '${(hour + 1).toString().padLeft(2, '0')}:00',
        ),
    ];
    final axis = WeekHourAxis.fromEvents(
      events: events,
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 72,
      allDayReserveHours: 2,
    );
    final host = weekAllDayHostSegments(
      axis: axis,
      occupiedHours: occupiedHourSlots(events),
      reserveCount: 2,
    );
    expect(host, isNotEmpty);
    expect(host.length, lessThanOrEqualTo(2));
  });

  test('extra visible hours are padding slots without timed events', () {
    final occupied = {10};
    final visible = visibleHourSlots(occupied, paddingBefore: 2, paddingAfter: 1);
    expect(visible, {8, 9, 10, 11});
    expect(
      weekExtraVisibleHours(visibleHours: visible, occupiedHours: occupied),
      {8, 9, 11},
    );
    final axis = WeekHourAxis.fromEvents(
      events: [
        _timed(id: 'a', day: day, start: '10:00', end: '11:00'),
      ],
      hideEmptyHours: true,
      expanded: false,
      paddingBefore: 2,
      paddingAfter: 1,
      allDayReserveHours: 0,
    );
    final host = weekLeadingExtraHourSegments(
      axis: axis,
      extraHours: weekExtraVisibleHours(
        visibleHours: visible,
        occupiedHours: occupied,
      ),
    );
    expect(host.map((s) => s.hour).toList(), [8, 9]);
  });

  test('snap rounds to 15 minutes', () {
    expect(snapWeekMinutes(7), 0);
    expect(snapWeekMinutes(8), 15);
    expect(snapWeekMinutes(22), 15);
    expect(snapWeekMinutes(23), 30);
    expect(snapWeekMinutes(1432), 24 * 60 - 15);
    expect(snapWeekMinutes(1433), 24 * 60);
  });

  test('collapse keeps occupied hours plus configurable padding', () {
    final events = [_timed(id: 'a', day: day, start: '10:00', end: '11:00')];
    final occupied = occupiedHourSlots(events);
    expect(occupied, {10});
    expect(
      visibleHourSlots(occupied, paddingBefore: 1, paddingAfter: 1),
      {9, 10, 11},
    );
    expect(
      visibleHourSlots(occupied, paddingBefore: 2, paddingAfter: 1),
      {8, 9, 10, 11},
    );
  });

  test('empty week shows 8-18 range', () {
    expect(visibleHourSlots({}), {for (var hour = 8; hour < 18; hour++) hour});
  });

  test('collapsed axis maps visible hours linearly and gutters stay short', () {
    final axis = WeekHourAxis.fromEvents(
      events: [_timed(id: 'a', day: day, start: '10:00', end: '11:00')],
      hideEmptyHours: true,
      expanded: false,
      paddingBefore: 1,
      paddingAfter: 1,
    );
    expect(axis.yForMinutes(10 * 60), kWeekHourGutterHeight + kWeekHourHeight);
    expect(
      axis.yForMinutes(11 * 60),
      kWeekHourGutterHeight + kWeekHourHeight * 2,
    );
    final gutters = axis.segments.where((segment) => !segment.isHour);
    expect(gutters, isNotEmpty);
    expect(
      gutters.every((segment) => segment.height == kWeekHourGutterHeight),
      isTrue,
    );
    expect(axis.totalHeight, lessThan(24 * kWeekHourHeight));
  });

  test('expanded axis is a full 24h grid', () {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: true,
      expanded: true,
    );
    expect(axis.segments.where((segment) => segment.isHour), hasLength(24));
    expect(axis.totalHeight, 24 * kWeekHourHeight);
    expect(axis.minutesForY(kWeekHourHeight * 2), 2 * 60);
    // ~12 minutes into the hour → snaps to :15 regardless of hourHeight.
    expect(
      axis.snapMinutesForY(kWeekHourHeight * 2 + kWeekHourHeight * 0.2),
      2 * 60 + 15,
    );
  });

  test('overlap packing puts intersecting events in columns', () {
    final packed = packWeekTimedEvents([
      _timed(id: 'a', day: day, start: '10:00', end: '12:00'),
      _timed(id: 'b', day: day, start: '11:00', end: '13:00'),
    ]);
    expect(packed, hasLength(2));
    expect(packed.map((item) => item.columnCount).toSet(), {2});
    expect(packed.map((item) => item.columnIndex).toSet(), {0, 1});
  });

  test('GCal overlap keeps almost full day width, not 50/50 columns', () {
    final packed = packWeekTimedEvents([
      _timed(id: 'a', day: day, start: '10:00', end: '12:00'),
      _timed(id: 'b', day: day, start: '11:00', end: '13:00'),
    ]);
    expect(packed, hasLength(2));
    expect(packed.map((item) => item.leftFraction).toSet().length, 2);
    for (final item in packed) {
      expect(item.widthFraction, greaterThan(0.7));
    }
    expect(packed.every((item) => item.widthFraction == 0.5), isFalse);
  });

  test('hoursCoveredByMinuteRange covers half-open end hour', () {
    expect(hoursCoveredByMinuteRange(11 * 60, 12 * 60 + 30), {11, 12});
    expect(hoursCoveredByMinuteRange(10 * 60, 11 * 60), {10});
  });

  test('collapsed axis includes selected slot hours so frame Y stays valid', () {
    final events = [
      _timed(id: 'a', day: day, start: '08:00', end: '09:00'),
      _timed(id: 'b', day: day, start: '18:00', end: '19:00'),
    ];
    final withoutSlot = WeekHourAxis.fromEvents(
      events: events,
      hideEmptyHours: true,
      expanded: false,
      paddingBefore: 0,
      paddingAfter: 0,
    );
    final withSlot = WeekHourAxis.fromEvents(
      events: events,
      hideEmptyHours: true,
      expanded: false,
      paddingBefore: 0,
      paddingAfter: 0,
      extraRangeStartMinutes: 11 * 60,
      extraRangeEndMinutes: 12 * 60 + 30,
    );

    final withoutHours = withoutSlot.segments
        .where((s) => s.isHour)
        .map((s) => s.hour)
        .toSet();
    expect(withoutHours.contains(11), isFalse);
    expect(withoutHours.contains(12), isFalse);

    final withHours = withSlot.segments
        .where((s) => s.isHour)
        .map((s) => s.hour)
        .toSet();
    expect(withHours.contains(11), isTrue);
    expect(withHours.contains(12), isTrue);

    final top = withSlot.yForMinutes(11 * 60);
    final bottom = withSlot.yForMinutes(12 * 60 + 30);
    expect(bottom, greaterThan(top));
    expect(bottom, lessThan(withSlot.totalHeight));
  });

  test('expanded with selectedSlot keeps full day for gestures', () {
    final events = [
      _timed(id: 'a', day: day, start: '10:00', end: '11:00'),
    ];
    final axis = WeekHourAxis.fromEvents(
      events: events,
      hideEmptyHours: true,
      expanded: true,
      extraRangeStartMinutes: 14 * 60,
      extraRangeEndMinutes: 15 * 60,
    );
    expect(axis.segments.where((s) => s.isHour), hasLength(24));
  });
}
