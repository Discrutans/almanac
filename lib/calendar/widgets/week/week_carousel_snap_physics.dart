import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_event_index.dart';
import '../../calendar_month_grid.dart';

/// Горизонтальная прокрутка недельной карусели с фиксацией по колонке дня.
///
/// После отпускания пальца или fling позиция выравнивается так, что в viewport
/// видны ровно [DateCellLayout.weekCarouselVisibleDays] целых дней.
/// Порог «сильного» fling для перехода через дополнительный день.
const weekCarouselStrongFlingVelocity = 1200.0;

/// Порог протяжки при отпускании пальца у края для перехода на соседнюю неделю.
const weekCarouselEdgeReleasePullThreshold = 24.0;

/// Длительность программной прокрутки при смене недели (не влияет на snap жеста).
const weekCarouselWeekTransitionDuration = Duration(milliseconds: 200);

/// Максимальный индекс дня недели (пн=0 … вс=6) для snap карусели.
const weekCarouselMaxWeekDayIndex = 6;

/// Недель до выбранной в непрерывной ленте (запас, чтобы не пересобирать список).
const weekCarouselWindowWeeksBehind = WeekLoadWindow.weeksBehind;

/// Недель после выбранной в непрерывной ленте.
const weekCarouselWindowWeeksAhead = WeekLoadWindow.weeksAhead;

/// Если выбранная неделя ближе к краю окна — сдвигаем ленту.
const weekCarouselWindowShiftMarginWeeks = 3;

/// Понедельник, с которого начинается окно карусели вокруг [selectedDate].
DateTime weekCarouselWindowStartFor(
  DateTime selectedDate, {
  int weeksBehind = weekCarouselWindowWeeksBehind,
}) {
  final weekStart = calendarWeekStartMonday(selectedDate);
  return calendarDayKey(weekStart.subtract(Duration(days: 7 * weeksBehind)));
}

/// Непрерывные дни окна карусели (без разрывов между неделями).
List<DateTime> weekCarouselWindowDates({
  required DateTime windowStart,
  int weeksBehind = weekCarouselWindowWeeksBehind,
  int weeksAhead = weekCarouselWindowWeeksAhead,
}) {
  final count = 7 * (weeksBehind + 1 + weeksAhead);
  return List.generate(
    count,
    (index) => calendarDayKey(windowStart.add(Duration(days: index))),
  );
}

bool weekCarouselWindowNeedsShift({
  required DateTime windowStart,
  required DateTime selectedDate,
  int weeksBehind = weekCarouselWindowWeeksBehind,
  int weeksAhead = weekCarouselWindowWeeksAhead,
  int marginWeeks = weekCarouselWindowShiftMarginWeeks,
}) {
  final weekStart = calendarWeekStartMonday(selectedDate);

  final weeksFromStart = weekStart.difference(windowStart).inDays ~/ 7;
  final weekCount = weeksBehind + 1 + weeksAhead;
  return weeksFromStart < marginWeeks ||
      weeksFromStart > weekCount - 1 - marginWeeks;
}

/// Колонки карусели: дни вне недели [selectedDate] — «призраки».
List<({DateTime date, bool ghost})> weekCarouselLanes({
  required List<DateTime> dates,
  required DateTime selectedDate,
}) {
  if (dates.isEmpty) return const [];
  return [
    for (final date in dates)
      (date: date, ghost: !isSameCalendarWeek(date, selectedDate)),
  ];
}

/// Колонки карусели: весь месяц; дни вне [selectedWeekDates] — «призраки».
List<({DateTime date, bool ghost})> weekCarouselMonthLanes(
  DateTime focusedMonth,
  List<DateTime> selectedWeekDates,
) {
  if (selectedWeekDates.isEmpty) return const [];
  final selected = selectedWeekDates[selectedWeekDates.length ~/ 2];
  return weekCarouselLanes(
    dates: monthGridDates(focusedMonth),
    selectedDate: selected,
  );
}

/// Индекс колонки для даты в сетке месяца.
int weekCarouselLaneIndexForDate(List<DateTime> gridDates, DateTime date) {
  final index = gridDates.indexWhere((day) => isSameCalendarDay(day, date));
  return index < 0 ? 0 : index;
}

/// Максимальный snap-индекс для [laneCount] колонок и [visibleColumns] видимых.
int weekCarouselMaxSnapPage({
  required int laneCount,
  required int visibleColumns,
}) {
  if (laneCount <= visibleColumns) return 0;
  return laneCount - visibleColumns;
}

/// Горизонтальный отступ контента карусели — центрирует первый/последний день на min/max.
double weekCarouselHorizontalPadding({
  required double viewportDimension,
  required double columnWidth,
}) {
  if (viewportDimension <= 0 || columnWidth <= 0) return 0;
  return (viewportDimension - columnWidth) / 2;
}

/// Максимальное смещение прокрутки для [laneCount] колонок и [visibleColumns] видимых.
double weekCarouselMaxScrollOffset({
  required double columnWidth,
  required int laneCount,
  required int visibleColumns,
}) {
  if (columnWidth <= 0 || laneCount <= visibleColumns) return 0;
  return (laneCount - visibleColumns) * columnWidth;
}

/// Индекс центральной колонки при [visibleColumns] видимых днях.
int weekCarouselCenterColumnOffset({int visibleColumns = 3}) =>
    visibleColumns ~/ 2;

/// Три видимых дня карусели: вчера, центр, завтра.
List<DateTime> weekCarouselVisibleDatesAround(DateTime center) {
  final day = calendarDayKey(center);
  return [
    calendarDayKey(day.subtract(const Duration(days: 1))),
    day,
    calendarDayKey(day.add(const Duration(days: 1))),
  ];
}

/// Смещение прокрутки, при котором день [dayIndex] оказывается в центре viewport.
double weekCarouselScrollOffsetForDayIndex({
  required int dayIndex,
  required double columnWidth,
  int visibleColumns = 3,
}) {
  if (columnWidth <= 0 || dayIndex < 0) return 0;
  final centerOffset = weekCarouselCenterColumnOffset(
    visibleColumns: visibleColumns,
  );
  return (dayIndex - centerOffset) * columnWidth;
}

/// Индекс дня в центре viewport по текущему смещению прокрутки.
int weekCarouselDayIndexForScrollOffset({
  required double offset,
  required double columnWidth,
  required int dayCount,
  int visibleColumns = 3,
}) {
  if (columnWidth <= 0 || dayCount <= 0) return 0;
  final centerOffset = weekCarouselCenterColumnOffset(
    visibleColumns: visibleColumns,
  );

  final leftIndex = (offset / columnWidth).round();
  return (leftIndex + centerOffset).clamp(0, dayCount - 1);
}

/// Ширина viewport карусели по ширине колонки.
double weekCarouselViewportWidth(double columnWidth, {int visibleDays = 3}) {
  if (columnWidth <= 0 || visibleDays <= 0) return 0;
  return columnWidth * visibleDays;
}

ScrollPhysics weekCarouselSnapScrollPhysics(
  double columnWidth, {
  int minSnapPage = 0,
  int? maxSnapPage,
}) {
  if (columnWidth <= 0) return const ClampingScrollPhysics();
  return WeekCarouselSnapScrollPhysics(
    columnWidth: columnWidth,
    minSnapPage: minSnapPage,
    maxSnapPage: maxSnapPage,
  ).applyTo(const ClampingScrollPhysics());
}

/// Длительность программного притяжения (тап). Жест использует [weekCarouselSnapSpring].
///
/// Длительность в wall-clock; тикер всё равно бьётся в частоту экрана (60–120 Hz).
Duration weekCarouselAttractDuration({
  required double distance,
  required double columnWidth,
}) {
  return almanacAttractDuration(distance: distance, unitExtent: columnWidth);
}

/// Почти критическое затухание: без отскока, интегрируется по dt vsync (90/120 Hz).
const weekCarouselSnapSpring = SpringDescription(
  mass: 0.75,
  stiffness: 170,
  damping: 23.7,
);

class WeekCarouselSnapScrollPhysics extends ScrollPhysics {
  const WeekCarouselSnapScrollPhysics({
    required this.columnWidth,
    this.minSnapPage = 0,
    this.maxSnapPage,
    super.parent,
  });

  final double columnWidth;
  final int minSnapPage;
  final int? maxSnapPage;

  @override
  WeekCarouselSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WeekCarouselSnapScrollPhysics(
      columnWidth: columnWidth,
      minSnapPage: minSnapPage,
      maxSnapPage: maxSnapPage,
      parent: buildParent(ancestor),
    );
  }

  double _page(ScrollMetrics position) => position.pixels / columnWidth;

  double _pixels(double page) => page * columnWidth;

  double _clampSnapPage(double page, ScrollMetrics position) {
    final maxPage =
        maxSnapPage?.toDouble() ??
        (position.maxScrollExtent / columnWidth).floorToDouble();
    return page.clamp(minSnapPage.toDouble(), maxPage);
  }

  double _targetPage(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    var page = _page(position);
    // Дополнительный шаг — только при сильном fling, иначе прокрутка «скачет».
    if (velocity < -weekCarouselStrongFlingVelocity) {
      page -= 0.5;
    } else if (velocity > weekCarouselStrongFlingVelocity) {
      page += 0.5;
    }
    return _clampSnapPage(page.roundToDouble(), position);
  }

  double _clampPixels(ScrollMetrics position, double pixels) {
    return pixels.clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  /// Тighter settle than the default ~1px: on 120 Hz a last-frame jump is visible.

  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    final parent = super.toleranceFor(metrics);
    return Tolerance(
      distance: parent.distance * 0.25,
      time: parent.time,
      velocity: parent.velocity * 0.45,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _clampPixels(
      position,
      _pixels(_targetPage(position, tolerance, velocity)),
    );
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      weekCarouselSnapSpring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}

/// Ближайшее смещение прокрутки, выровненное по ширине колонки дня.
double snapWeekCarouselOffset({
  required double offset,
  required double columnWidth,
  required double minExtent,
  required double maxExtent,
}) {
  if (columnWidth <= 0) {
    return offset.clamp(minExtent, maxExtent);
  }
  final snapped = (offset / columnWidth).roundToDouble() * columnWidth;
  return snapped.clamp(minExtent, maxExtent);
}
