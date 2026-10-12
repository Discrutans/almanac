import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import 'week_carousel_snap_physics.dart';
import 'week_drag_policy.dart';
import 'week_grid_slot.dart';
import 'week_hour_axis.dart';

/// Результат hit-test переноса на недельной сетке (carousel и wide grid).
class WeekDropTarget {
  const WeekDropTarget({
    required this.date,
    required this.columnIndex,
    required this.columnCount,
    this.ghost = false,
    this.minutesOfDay,
    this.isAllDayHost = false,
  });

  final DateTime date;
  final int columnIndex;
  final int columnCount;
  final bool ghost;
  final int? minutesOfDay;

  /// Pointer over reserved all-day host hours (notes/checklists zone).
  final bool isAllDayHost;

  WeekDropTarget copyWith({
    DateTime? date,
    int? columnIndex,
    int? columnCount,
    bool? ghost,
    int? minutesOfDay,
    bool? isAllDayHost,
  }) {
    return WeekDropTarget(
      date: date ?? this.date,
      columnIndex: columnIndex ?? this.columnIndex,
      columnCount: columnCount ?? this.columnCount,
      ghost: ghost ?? this.ghost,
      minutesOfDay: minutesOfDay ?? this.minutesOfDay,
      isAllDayHost: isAllDayHost ?? this.isAllDayHost,
    );
  }

  /// Carousel alias for [columnIndex].
  int get laneIndex => columnIndex;

  /// Carousel alias for [columnCount].
  int get laneCount => columnCount;

  bool get isGridEdgePrevious => columnIndex == 0;

  bool get isGridEdgeNext => columnIndex == columnCount - 1;
}

/// Resolve drop under [globalPosition] for a horizontal strip of day columns.
///
/// [scrollOffset] is horizontal scroll (carousel); use 0 for the wide grid.
/// [leftInset] shifts day columns (legacy gutter); use 0 when labels overlay.
WeekDropTarget? weekDropTargetAt({
  required Offset globalPosition,
  required RenderBox viewportBox,
  required double columnWidth,
  required List<DateTime> dayDates,
  double scrollOffset = 0,
  double leftInset = 0,
  double headerHeight = 0,
  double topDockHeight = 0,
  double timedScrollOffset = 0,
  WeekHourAxis? axis,
  int allDayReserveHours = 0,
  bool Function(int columnIndex)? isGhostColumn,
}) {
  if (columnWidth <= 0 || dayDates.isEmpty) return null;

  final local = viewportBox.globalToLocal(globalPosition);
  if (local.dx < 0 || local.dx > viewportBox.size.width) return null;
  if (local.dy < 0 || local.dy > viewportBox.size.height) return null;

  final contentX = local.dx - leftInset + scrollOffset;
  if (contentX < 0) return null;
  final columnIndex = (contentX / columnWidth).floor();
  if (columnIndex < 0 || columnIndex >= dayDates.length) return null;

  final date = calendarDayKey(dayDates[columnIndex]);
  final ghost = isGhostColumn?.call(columnIndex) ?? false;

  int? minutes;
  var isAllDayHost = false;
  if (axis != null && local.dy >= headerHeight) {
    final timedViewportHeight = viewportBox.size.height - headerHeight;
    final contentY = local.dy - headerHeight + timedScrollOffset;
    minutes = weekTimedMinutesForContentY(
      axis: axis,
      contentY: contentY,
      viewportHeight: timedViewportHeight,
      snap: true,
      topDockHeight: topDockHeight,
    );
    if (allDayReserveHours > 0) {
      final host = weekAllDayHostSegments(
        axis: axis,
        occupiedHours: const {},
        reserveCount: allDayReserveHours,
      );
      if (host.isNotEmpty) {
        final hostTop = host.first.y + topDockHeight;
        final hostBottom = host.last.y + host.last.height + topDockHeight;
        final axisY = contentY -
            weekTimedBottomAlignPad(
              axisHeight: topDockHeight + axis.totalHeight,
              viewportHeight: timedViewportHeight,
            );
        if (axisY >= hostTop && axisY < hostBottom) {
          isAllDayHost = true;
        }
      }
    }
  }

  return WeekDropTarget(
    date: date,
    columnIndex: columnIndex,
    columnCount: dayDates.length,
    ghost: ghost,
    minutesOfDay: minutes,
    isAllDayHost: isAllDayHost,
  );
}

/// Carousel lanes (including ghosts) → [WeekDropTarget].
WeekDropTarget? weekCarouselDropTargetAt({
  required Offset globalPosition,
  required RenderBox viewportBox,
  required double scrollOffset,
  required double columnWidth,
  required List<DateTime> laneDates,
  required DateTime selectedDate,
  double headerHeight = 0,
  double topDockHeight = 0,
  double timedScrollOffset = 0,
  WeekHourAxis? axis,
  int allDayReserveHours = 0,
}) {
  if (columnWidth <= 0 || laneDates.isEmpty) return null;
  final lanes = weekCarouselLanes(dates: laneDates, selectedDate: selectedDate);
  final dates = [for (final lane in lanes) lane.date];
  return weekDropTargetAt(
    globalPosition: globalPosition,
    viewportBox: viewportBox,
    columnWidth: columnWidth,
    dayDates: dates,
    scrollOffset: scrollOffset,
    headerHeight: headerHeight,
    topDockHeight: topDockHeight,
    timedScrollOffset: timedScrollOffset,
    axis: axis,
    allDayReserveHours: allDayReserveHours,
    isGhostColumn: (index) => lanes[index].ghost,
  );
}

/// Build preview from a hit-test result (null if minutes missing / all-day host).
///
/// Ghost lanes (days outside the selected week) are valid drop targets while
/// dragging so the contour shows at week edges and on the next/previous week.
WeekDropPreview? weekDropPreviewForTarget({
  required WeekDropTarget? target,
  AppEvent? dragging,
  WeekGridSlot? draggingSlot,
}) {
  if (target == null) return null;
  if (target.minutesOfDay == null || target.isAllDayHost) return null;
  if (draggingSlot != null) {
    return WeekDropPreview.fromSlot(
      date: target.date,
      slot: draggingSlot,
      startMinutes: target.minutesOfDay!,
    );
  }
  if (dragging == null || !dragging.isTimed) return null;
  return WeekDropPreview.fromEvent(
    date: target.date,
    event: dragging,
    startMinutes: target.minutesOfDay!,
  );
}

/// Resolve create-slot drop: new day + start, duration preserved.
({WeekGridSlot? slot, bool accepted}) weekResolveSlotDrop({
  required WeekGridSlot slot,
  required WeekDropTarget? target,
}) {
  if (target == null) {
    return (slot: null, accepted: false);
  }
  if (target.isAllDayHost || target.minutesOfDay == null) {
    return (slot: null, accepted: false);
  }
  final moved = slot.movedTo(
    date: target.date,
    startMinutes: target.minutesOfDay!,
  );
  if (moved == slot) {
    return (slot: moved, accepted: false);
  }
  return (slot: moved, accepted: true);
}

/// Resolve commit payload: start time (or null for all-day).
///
/// Personal timed overlaps are allowed (cascade layout on the grid).
({DateTime date, TimeOfDay? startTime, bool accepted}) weekResolveDropCommit({
  required AppEvent event,
  required WeekDropTarget? target,
}) {
  if (target == null) {
    return (date: event.dateTimeRange.start, startTime: null, accepted: false);
  }
  if (!weekEventMayDrop(event)) {
    return (date: target.date, startTime: null, accepted: false);
  }

  TimeOfDay? startTime;
  if (event.isTimed &&
      !target.isAllDayHost &&
      target.minutesOfDay != null) {
    startTime = timeOfDayFromMinutes(
      target.minutesOfDay!.clamp(0, 24 * 60 - kWeekTimeSnapMinutes),
    );
  }

  // Same timed slot no-op.
  if (startTime != null &&
      event.isTimed &&
      event.isOnDate(target.date)) {
    final movedMinutes = startTime.hour * 60 + startTime.minute;
    if (movedMinutes == eventStartMinutesOfDay(event)) {
      return (date: target.date, startTime: startTime, accepted: false);
    }
  }

  // Same-day all-day no-op.
  if (startTime == null && event.isOnDate(target.date)) {
    return (date: target.date, startTime: null, accepted: false);
  }

  return (date: target.date, startTime: startTime, accepted: true);
}
