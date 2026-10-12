import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import 'week_day_timeline.dart';

/// Сдвиг пересекающейся карточки (~12% дня, 10–14 px).
const double kWeekOverlapIndentFraction = 0.12;
const double kWeekOverlapIndentMinPx = 10;
const double kWeekOverlapIndentMaxPx = 14;
const double kWeekOverlapGutterFraction = 0.03;
const double kWeekOverlapGutterPx = 3;
const double kWeekOverlapMinWidthFraction = 0.7;

double weekOverlapIndentPx(double dayWidth) {
  if (dayWidth <= 0) return kWeekOverlapIndentMinPx;
  return (dayWidth * kWeekOverlapIndentFraction).clamp(
    kWeekOverlapIndentMinPx,
    kWeekOverlapIndentMaxPx,
  );
}

class WeekTimedPlacement {
  const WeekTimedPlacement({
    required this.event,
    required this.startMinutes,
    required this.endMinutes,
    required this.columnIndex,
    required this.columnCount,
  });

  final AppEvent event;
  final int startMinutes;
  final int endMinutes;
  final int columnIndex;
  final int columnCount;

  /// Каскад как в Google Calendar: отступ колонки, почти вся ширина дня.
  double get leftFraction => kWeekOverlapIndentFraction * columnIndex;

  double get widthFraction {
    final remaining = 1 - leftFraction - kWeekOverlapGutterFraction;
    if (remaining < kWeekOverlapMinWidthFraction) {
      return kWeekOverlapMinWidthFraction;
    }
    return remaining;
  }

  double leftPx(double dayWidth) => weekOverlapIndentPx(dayWidth) * columnIndex;

  double widthPx(double dayWidth) {
    if (columnIndex == 0 && columnCount <= 1) return dayWidth;
    final left = leftPx(dayWidth);
    final remaining = dayWidth - left - kWeekOverlapGutterPx;
    final minWidth = dayWidth * kWeekOverlapMinWidthFraction;
    return remaining < minWidth ? minWidth : remaining;
  }

  /// Visible strip for title/time before the next cascade column.
  double visibleTextWidthPx(double dayWidth) {
    if (columnCount <= 1) return widthPx(dayWidth);
    final left = leftPx(dayWidth);
    final nextLeft = columnIndex + 1 < columnCount
        ? weekOverlapIndentPx(dayWidth) * (columnIndex + 1)
        : dayWidth;
    final visible = nextLeft - left - kWeekOverlapGutterPx;
    final fill = widthPx(dayWidth);
    if (visible <= 8) return 8;
    return visible < fill ? visible : fill;
  }
}

class _PackedEvent {
  _PackedEvent({required this.event, required this.start, required this.end});

  final AppEvent event;
  final int start;
  final int end;
  int column = 0;
  int columnCount = 1;
}

/// Упаковка пересечений в колонки, как в Google Calendar.
///
/// Смены — полный underlay (колонка 0); личные упаковываются отдельно сверху.
List<WeekTimedPlacement> packWeekTimedEvents(List<AppEvent> events) {
  final shifts = <_PackedEvent>[];
  final personal = <_PackedEvent>[];
  for (final event in events) {
    if (!event.isTimed) continue;
    final packed = _PackedEvent(
      event: event,
      start: eventStartMinutesOfDay(event),
      end: eventDisplayEndMinutesOfDay(event).clamp(
        eventStartMinutesOfDay(event) + kWeekTimeSnapMinutes,
        24 * 60,
      ),
    );
    if (event.isFromWorkSchedule) {
      shifts.add(packed);
    } else {
      personal.add(packed);
    }
  }

  shifts.sort((a, b) {
    final startCmp = a.start.compareTo(b.start);
    if (startCmp != 0) return startCmp;
    return b.end.compareTo(a.end);
  });
  for (final item in shifts) {
    item.column = 0;
    item.columnCount = 1;
  }

  personal.sort((a, b) {
    final startCmp = a.start.compareTo(b.start);
    if (startCmp != 0) return startCmp;
    return b.end.compareTo(a.end);
  });

  final columnEnds = <int>[];
  for (final item in personal) {
    var placed = false;
    for (var i = 0; i < columnEnds.length; i++) {
      if (columnEnds[i] <= item.start) {
        item.column = i;
        columnEnds[i] = item.end;
        placed = true;
        break;
      }
    }
    if (!placed) {
      item.column = columnEnds.length;
      columnEnds.add(item.end);
    }
  }

  for (var i = 0; i < personal.length; i++) {
    var clusterEnd = personal[i].end;
    var maxColumn = personal[i].column;
    var j = i + 1;
    while (j < personal.length && personal[j].start < clusterEnd) {
      if (personal[j].end > clusterEnd) clusterEnd = personal[j].end;
      if (personal[j].column > maxColumn) maxColumn = personal[j].column;
      j++;
    }
    final count = maxColumn + 1;
    for (var k = i; k < j; k++) {
      personal[k].columnCount = count;
    }
    i = j - 1;
  }

  return [
    for (final item in shifts)
      WeekTimedPlacement(
        event: item.event,
        startMinutes: item.start,
        endMinutes: item.end,
        columnIndex: item.column,
        columnCount: item.columnCount,
      ),
    for (final item in personal)
      WeekTimedPlacement(
        event: item.event,
        startMinutes: item.start,
        endMinutes: item.end,
        columnIndex: item.column,
        columnCount: item.columnCount,
      ),
  ];
}

int maxAllDayCount(Iterable<List<AppEvent>> days) {
  var maxCount = 0;
  for (final events in days) {
    final count = weekAllDayEvents(events).length;
    if (count > maxCount) maxCount = count;
  }
  return maxCount;
}
