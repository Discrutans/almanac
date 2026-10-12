import 'dart:ui' show Rect;

import '../../calendar_types.dart';
import '../../event_time_utils.dart';

const double kWeekHourHeight = 72;
const double kWeekHourHeightMin = 48;
const double kWeekHourHeightMax = 140;
const double kWeekHourGutterHeight = 10;
const double kWeekHourLabelWidth = 54;
const double kWeekHourAllDayTileHeight = 28;
const double kWeekHourAllDayGap = 2;
const double kWeekHourMinEventHeight = 22;
const double kWeekHourResizeHandleExtent = 40;
/// Gap around each square hour cell (same for empty grid and event fill).
const double kWeekHourCellInset = 2;
/// Shared corner radius for empty hour cells and event fills.
const double kWeekHourCellRadius = 8;
const double kWeekHourLabelRightPad = 4;
const double kWeekResizeHandleSize = 18;
const int kWeekEmptyRangeStartHour = 8;
const int kWeekEmptyRangeEndHour = 18;
const int kWeekHourPaddingMin = 0;
const int kWeekHourPaddingMax = 6;
const int kWeekHourPaddingBeforeDefault = 2;
const int kWeekHourPaddingAfterDefault = 1;
const int kWeekHourZoomLevelMin = 1;
const int kWeekHourZoomLevelMax = 2;
const int kWeekHourZoomLevelDefault = 1;

int clampWeekHourPadding(int value) =>
    value.clamp(kWeekHourPaddingMin, kWeekHourPaddingMax);

int clampWeekHourZoomLevel(int level) =>
    level.clamp(kWeekHourZoomLevelMin, kWeekHourZoomLevelMax);

/// Hour height from date-strip height × zoom level (1 / 2 / 3).
double weekHourHeightForZoom(double stripHeight, int level) {
  final strip = stripHeight.isFinite && stripHeight > 0
      ? stripHeight
      : kWeekHourHeight;
  return strip * clampWeekHourZoomLevel(level);
}

/// Nearest zoom level for [hourHeight] given [stripHeight].
int weekHourZoomLevelNearest(double stripHeight, double hourHeight) {
  var best = kWeekHourZoomLevelDefault;
  var bestDist = double.infinity;
  for (
    var level = kWeekHourZoomLevelMin;
    level <= kWeekHourZoomLevelMax;
    level++
  ) {
    final h = weekHourHeightForZoom(stripHeight, level);
    final d = (h - hourHeight).abs();
    if (d < bestDist) {
      bestDist = d;
      best = level;
    }
  }
  return best;
}

/// Fallback before strip measure; prefer [weekHourHeightForZoom].
@Deprecated('Use weekHourHeightForZoom(stripHeight, level) instead')
double weekSquareHourHeight(double columnWidth) {
  if (!columnWidth.isFinite || columnWidth <= 0) return kWeekHourHeight;
  return columnWidth.clamp(kWeekHourHeightMin, kWeekHourHeightMax);
}

enum WeekHourSegmentKind { hour, gutter }

class WeekHourSegment {
  const WeekHourSegment({
    required this.kind,
    required this.startHour,
    required this.endHourExclusive,
    required this.y,
    required this.height,
  });

  final WeekHourSegmentKind kind;
  final int startHour;
  final int endHourExclusive;
  final double y;
  final double height;

  bool get isHour => kind == WeekHourSegmentKind.hour;
  int get hour => startHour;
}

/// Вертикальная ось недели: минуты ↔ Y, collapse пустых часов по всей неделе.
class WeekHourAxis {
  const WeekHourAxis({
    required this.segments,
    this.hourHeight = kWeekHourHeight,
    this.gutterHeight = kWeekHourGutterHeight,
  });

  final List<WeekHourSegment> segments;
  final double hourHeight;
  final double gutterHeight;

  double get totalHeight {
    if (segments.isEmpty) return 0;
    final last = segments.last;
    return last.y + last.height;
  }

  factory WeekHourAxis.fromEvents({
    required Iterable<AppEvent> events,
    required bool hideEmptyHours,
    required bool expanded,
    double hourHeight = kWeekHourHeight,
    int paddingBefore = kWeekHourPaddingBeforeDefault,
    int paddingAfter = kWeekHourPaddingAfterDefault,
    int allDayReserveHours = 0,
    int? extraRangeStartMinutes,
    int? extraRangeEndMinutes,
  }) {
    final occupied = occupiedHourSlots(events);
    if (extraRangeStartMinutes != null && extraRangeEndMinutes != null) {
      occupied.addAll(
        hoursCoveredByMinuteRange(
          extraRangeStartMinutes,
          extraRangeEndMinutes,
        ),
      );
    }
    final visible = expanded || !hideEmptyHours
        ? {for (var hour = 0; hour < 24; hour++) hour}
        : ensureAllDayHostHours(
            visibleHourSlots(
              occupied,
              paddingBefore: paddingBefore,
              paddingAfter: paddingAfter,
            ),
            occupied: occupied,
            reserveCount: allDayReserveHours,
          );
    return WeekHourAxis(
      segments: buildHourSegments(visible, hourHeight: hourHeight),
      hourHeight: hourHeight,
    );
  }

  double yForMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60);
    if (segments.isEmpty) return 0;
    if (clamped >= 24 * 60) return totalHeight;

    final hour = clamped ~/ 60;
    final minuteInHour = clamped % 60;
    for (final segment in segments) {
      if (segment.isHour && segment.hour == hour) {
        return segment.y + hourHeight * (minuteInHour / 60.0);
      }
      if (!segment.isHour &&
          hour >= segment.startHour &&
          hour < segment.endHourExclusive) {
        final spanMinutes = (segment.endHourExclusive - segment.startHour) * 60;
        final local = clamped - segment.startHour * 60;
        final t = (local / spanMinutes).clamp(0.0, 1.0);
        return segment.y + segment.height * t;
      }
    }
    // Missing hour (should be rare): snap to nearest segment edge so frames
    // never stretch to totalHeight and steal hit-tests.
    return _yForOrphanMinutes(clamped);
  }

  double _yForOrphanMinutes(int minutes) {
    final hour = minutes ~/ 60;
    WeekHourSegment? before;
    WeekHourSegment? after;
    for (final segment in segments) {
      if (segment.endHourExclusive <= hour) {
        before = segment;
      } else if (after == null && segment.startHour > hour) {
        after = segment;
        break;
      } else if (after == null && segment.startHour >= hour) {
        after = segment;
        break;
      }
    }
    if (before != null) return before.y + before.height;
    if (after != null) return after.y;
    return totalHeight;
  }

  int minutesForY(double y) {
    if (y <= 0) return 0;
    if (y >= totalHeight) return 24 * 60;
    for (final segment in segments) {
      final bottom = segment.y + segment.height;
      if (y >= segment.y && y < bottom) {
        final t = segment.height <= 0 ? 0.0 : (y - segment.y) / segment.height;
        if (segment.isHour) {
          return (segment.hour * 60 + t * 60).round().clamp(0, 24 * 60);
        }
        final spanMinutes = (segment.endHourExclusive - segment.startHour) * 60;
        return (segment.startHour * 60 + t * spanMinutes).round().clamp(
          0,
          24 * 60,
        );
      }
    }
    return 24 * 60;
  }

  int snapMinutes(int minutes) => snapWeekMinutes(minutes);

  int snapMinutesForY(double y) => snapMinutes(minutesForY(y));
}

/// Y of [pinMinutes] relative to the current scroll offset.
double weekAxisViewportY({
  required WeekHourAxis axis,
  required int pinMinutes,
  required double scrollOffset,
  double bottomAlignPad = 0,
  double topDockHeight = 0,
}) {
  return bottomAlignPad +
      topDockHeight +
      axis.yForMinutes(pinMinutes) -
      scrollOffset;
}

/// Scroll offset that keeps [pinMinutes] at [viewportY] after the axis changes.
double weekAxisKeepVisibleOffset({
  required WeekHourAxis newAxis,
  required int pinMinutes,
  required double viewportY,
  required double maxScrollExtent,
  double bottomAlignPad = 0,
  double topDockHeight = 0,
}) {
  if (maxScrollExtent <= 0) return 0;
  return (bottomAlignPad +
          topDockHeight +
          newAxis.yForMinutes(pinMinutes) -
          viewportY)
      .clamp(0.0, maxScrollExtent);
}

/// Pin when the event time is unknown: one hour below the top, not midnight.
int weekAxisFallbackPinMinutes(WeekHourAxis axis, double scrollOffset) {
  return axis
      .snapMinutesForY(scrollOffset + kWeekHourHeight)
      .clamp(0, 24 * 60 - kWeekTimeSnapMinutes);
}

/// Y for the now-line, or null when [minutes] fall inside a collapsed gutter.
double? weekNowLineY(WeekHourAxis axis, int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  final hour = clamped ~/ 60;
  for (final segment in axis.segments) {
    if (segment.isHour && segment.hour == hour) {
      return axis.yForMinutes(clamped);
    }
  }
  return null;
}

Set<int> occupiedHourSlots(Iterable<AppEvent> events) {
  final list = events.toList();
  final parentsWithChildren = <String>{
    for (final event in list)
      if (event.parentEventId != null && event.parentEventId!.isNotEmpty)
        event.parentEventId!,
  };
  final hours = <int>{};
  for (final event in list) {
    if (!event.isTimed) continue;
    final start = eventStartMinutesOfDay(event);
    final end = eventDisplayEndMinutesOfDay(event);
    final firstHour = start ~/ 60;
    final lastHour = end <= start ? firstHour : ((end - 1) ~/ 60).clamp(0, 23);
    // Empty shift (no nested tasks): only keep boundary hours so the axis
    // compresses 08…17 into 08 + 17 with a gutter between.
    if (event.isFromWorkSchedule && !parentsWithChildren.contains(event.id)) {
      hours.add(firstHour.clamp(0, 23));
      hours.add(lastHour);
      continue;
    }
    for (var hour = firstHour; hour <= lastHour && hour <= 23; hour++) {
      hours.add(hour);
    }
  }
  return hours;
}

/// Hours touched by half-open [startMinutes, endMinutes).
Set<int> hoursCoveredByMinuteRange(int startMinutes, int endMinutes) {
  final start = startMinutes.clamp(0, 24 * 60);
  final end = endMinutes.clamp(0, 24 * 60);
  if (end <= start) return { (start ~/ 60).clamp(0, 23) };
  final firstHour = start ~/ 60;
  final lastHour = ((end - 1) ~/ 60).clamp(0, 23);
  return {
    for (var hour = firstHour; hour <= lastHour; hour++) hour,
  };
}

Set<int> visibleHourSlots(
  Set<int> occupied, {
  int paddingBefore = kWeekHourPaddingBeforeDefault,
  int paddingAfter = kWeekHourPaddingAfterDefault,
}) {
  if (occupied.isEmpty) {
    return {
      for (
        var hour = kWeekEmptyRangeStartHour;
        hour < kWeekEmptyRangeEndHour;
        hour++
      )
        hour,
    };
  }
  final before = clampWeekHourPadding(paddingBefore);
  final after = clampWeekHourPadding(paddingAfter);
  final visible = <int>{};
  for (final hour in occupied) {
    final start = (hour - before).clamp(0, 23);
    final end = (hour + after).clamp(0, 23);
    for (var h = start; h <= end; h++) {
      visible.add(h);
    }
  }
  return visible;
}

/// Часы, видимые только как padding (не заняты timed-событиями дня).
Set<int> weekExtraVisibleHours({
  required Set<int> visibleHours,
  required Set<int> occupiedHours,
}) {
  return {
    for (final hour in visibleHours)
      if (!occupiedHours.contains(hour)) hour,
  };
}

/// Ведущий блок padding-часов сверху видимого диапазона (для all-day чипов).
List<WeekHourSegment> weekLeadingExtraHourSegments({
  required WeekHourAxis axis,
  required Set<int> extraHours,
}) {
  if (extraHours.isEmpty) return const [];
  final hourSegments = [
    for (final segment in axis.segments)
      if (segment.isHour) segment,
  ];
  if (hourSegments.isEmpty) return const [];

  // Prefer contiguous free hours from the first visible hour downward.
  final leading = <WeekHourSegment>[];
  for (final segment in hourSegments) {
    if (!extraHours.contains(segment.hour)) break;
    leading.add(segment);
  }
  if (leading.isNotEmpty) return leading;

  // Else first contiguous free block anywhere in the axis.
  for (var i = 0; i < hourSegments.length; i++) {
    if (!extraHours.contains(hourSegments[i].hour)) continue;
    final block = <WeekHourSegment>[hourSegments[i]];
    for (var j = i + 1; j < hourSegments.length; j++) {
      if (!extraHours.contains(hourSegments[j].hour)) break;
      if (hourSegments[j].hour != hourSegments[j - 1].hour + 1) break;
      block.add(hourSegments[j]);
    }
    return block;
  }
  return const [];
}

/// Сколько ведущих host-часов нужно под стек all-day чипов.
int weekAllDayReserveHours(
  int chipCount, {
  double hourHeight = kWeekHourHeight,
}) {
  if (chipCount <= 0) return 0;
  final safeHeight = hourHeight <= 0 ? kWeekHourHeight : hourHeight;
  final stack =
      chipCount * kWeekHourAllDayTileHeight +
      (chipCount > 1 ? (chipCount - 1) * kWeekHourAllDayGap : 0) +
      kWeekHourCellInset * 2;
  final needed = (stack / safeHeight).ceil();
  return needed.clamp(1, 24);
}

/// Добавляет часы перед первым занятым, чтобы all-day было куда положить.
Set<int> ensureAllDayHostHours(
  Set<int> visible, {
  required Set<int> occupied,
  required int reserveCount,
}) {
  if (reserveCount <= 0) return visible;
  final result = {...visible};
  if (occupied.isEmpty) {
    // Empty-week range already has free hours.
    return result;
  }
  final firstOccupied = occupied.reduce((a, b) => a < b ? a : b);
  var added = 0;
  for (var h = firstOccupied - 1; h >= 0 && added < reserveCount; h--) {
    if (!occupied.contains(h)) {
      result.add(h);
      added++;
    }
  }
  // If nothing before (event at 00:00), take free hours after last occupied.
  if (added < reserveCount) {
    final lastOccupied = occupied.reduce((a, b) => a > b ? a : b);
    for (var h = lastOccupied + 1; h < 24 && added < reserveCount; h++) {
      if (!occupied.contains(h)) {
        result.add(h);
        added++;
      }
    }
  }
  return result;
}

/// Host-сегменты для all-day: свободные padding-часы, иначе первые N часов оси.
List<WeekHourSegment> weekAllDayHostSegments({
  required WeekHourAxis axis,
  required Set<int> occupiedHours,
  required int reserveCount,
}) {
  if (reserveCount <= 0) return const [];
  final hourSegments = [
    for (final segment in axis.segments)
      if (segment.isHour) segment,
  ];
  if (hourSegments.isEmpty) return const [];

  final visible = {for (final segment in hourSegments) segment.hour};
  final extra = weekExtraVisibleHours(
    visibleHours: visible,
    occupiedHours: occupiedHours,
  );
  final leading = weekLeadingExtraHourSegments(
    axis: axis,
    extraHours: extra,
  );
  if (leading.isNotEmpty) {
    return leading.take(reserveCount).toList(growable: false);
  }
  // Full axis / every hour occupied: still overlay chips on the leading hours.
  final take = reserveCount.clamp(1, hourSegments.length);
  return hourSegments.take(take).toList(growable: false);
}

/// Rect одной квадратной ячейки часа (одинаково для сетки и заливки событий).
Rect weekHourCellRect({
  required WeekHourSegment segment,
  required double width,
  double originY = 0,
}) {
  const inset = kWeekHourCellInset;
  final height = (segment.height - inset * 2).clamp(4.0, segment.height);
  return Rect.fromLTWH(
    inset,
    segment.y - originY + inset,
    (width - inset * 2).clamp(0.0, width),
    height,
  );
}

/// Часовые сегменты оси, пересекающие интервал события.
List<WeekHourSegment> weekHourSegmentsOverlappingRange({
  required WeekHourAxis axis,
  required int startMinutes,
  required int endMinutes,
}) {
  final start = startMinutes.clamp(0, 24 * 60);
  final end = endMinutes.clamp(0, 24 * 60);
  if (end <= start) return const [];
  return [
    for (final segment in axis.segments)
      if (segment.isHour &&
          segment.startHour * 60 < end &&
          segment.endHourExclusive * 60 > start)
        segment,
  ];
}

List<WeekHourSegment> buildHourSegments(
  Set<int> visibleHours, {
  double hourHeight = kWeekHourHeight,
  double gutterHeight = kWeekHourGutterHeight,
}) {
  final segments = <WeekHourSegment>[];
  var y = 0.0;
  var hour = 0;
  while (hour < 24) {
    if (visibleHours.contains(hour)) {
      segments.add(
        WeekHourSegment(
          kind: WeekHourSegmentKind.hour,
          startHour: hour,
          endHourExclusive: hour + 1,
          y: y,
          height: hourHeight,
        ),
      );
      y += hourHeight;
      hour++;
      continue;
    }
    final start = hour;
    while (hour < 24 && !visibleHours.contains(hour)) {
      hour++;
    }
    segments.add(
      WeekHourSegment(
        kind: WeekHourSegmentKind.gutter,
        startHour: start,
        endHourExclusive: hour,
        y: y,
        height: gutterHeight,
      ),
    );
    y += gutterHeight;
  }
  return segments;
}

@Deprecated('all-day lives in padding hours; always 0')
double weekAllDayBandHeightForCounts(int maxCount, {double? hourHeight}) {
  // All-day lives inside padding hour cells on the axis — no separate dock.
  return 0;
}

/// Высота scroll-child timed-сетки: не короче viewport, чтобы Align.bottom работал.
double weekTimedScrollExtent({
  required double contentHeight,
  required double viewportHeight,
}) {
  if (viewportHeight <= 0) return contentHeight;
  return contentHeight < viewportHeight ? viewportHeight : contentHeight;
}

/// Пустой зазор сверху при bottom-align короткой оси в высоком viewport.
double weekTimedBottomAlignPad({
  required double axisHeight,
  required double viewportHeight,
}) {
  if (viewportHeight <= 0 || axisHeight >= viewportHeight) return 0;
  return viewportHeight - axisHeight;
}

/// Y в scroll-content → минуты оси с учётом bottom-align и all-day dock сверху.
int weekTimedMinutesForContentY({
  required WeekHourAxis axis,
  required double contentY,
  required double viewportHeight,
  bool snap = false,
  double topDockHeight = 0,
}) {
  final pad = weekTimedBottomAlignPad(
    axisHeight: topDockHeight + axis.totalHeight,
    viewportHeight: viewportHeight,
  );
  final axisY = contentY - pad - topDockHeight;
  return snap ? axis.snapMinutesForY(axisY) : axis.minutesForY(axisY);
}
