import 'dart:math' as math;
import 'package:almanac/calendar/calendar_month_grid.dart';
import 'package:almanac/calendar/widgets/chrome/calendar_day_badge.dart';
import 'package:almanac/calendar/widgets/chrome/date_cell.dart';
import 'package:almanac/calendar/widgets/week/week_carousel_snap_physics.dart';
import 'package:almanac/core/theme/almanac_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weekCarouselMonthLanes marks days outside selected week as ghost', () {
    final week = [
      DateTime(2026, 6, 15),
      DateTime(2026, 6, 16),
      DateTime(2026, 6, 17),
      DateTime(2026, 6, 18),
      DateTime(2026, 6, 19),
      DateTime(2026, 6, 20),
      DateTime(2026, 6, 21),
    ];
    final lanes = weekCarouselMonthLanes(DateTime(2026, 6, 1), week);
    expect(lanes.length, monthGridDates(DateTime(2026, 6, 1)).length);

    final active = lanes.where((lane) => !lane.ghost).toList();
    expect(active.length, 7);
    expect(active.map((lane) => lane.date), week);

    final june14 = lanes.firstWhere(
      (lane) => lane.date == DateTime(2026, 6, 14),
    );
    expect(june14.ghost, isTrue);
  });

  test('weekCarouselDayIndexForScrollOffset picks center column', () {
    expect(
      weekCarouselDayIndexForScrollOffset(
        offset: 0,
        columnWidth: 120,
        dayCount: 35,
      ),
      1,
    );
    expect(
      weekCarouselDayIndexForScrollOffset(
        offset: 120,
        columnWidth: 120,
        dayCount: 35,
      ),
      2,
    );
    expect(
      weekCarouselDayIndexForScrollOffset(
        offset: 720,
        columnWidth: 120,
        dayCount: 35,
      ),
      7,
    );
    expect(
      weekCarouselDayIndexForScrollOffset(
        offset: 60,
        columnWidth: 120,
        dayCount: 35,
      ),
      2,
    );
  });

  test('weekCarouselLaneIndexForDate finds lane in month grid', () {
    final grid = monthGridDates(DateTime(2026, 6, 1));
    expect(
      weekCarouselLaneIndexForDate(grid, DateTime(2026, 6, 17)),
      grid.indexWhere((date) => date == DateTime(2026, 6, 17)),
    );
  });

  test('weekCarouselMaxSnapPage accounts for visible columns', () {
    expect(weekCarouselMaxSnapPage(laneCount: 35, visibleColumns: 3), 32);
    expect(weekCarouselMaxSnapPage(laneCount: 3, visibleColumns: 3), 0);
  });

  test('weekCarouselScrollOffsetForDayIndex centers day in viewport', () {
    expect(
      weekCarouselScrollOffsetForDayIndex(dayIndex: 0, columnWidth: 120),
      -120,
    );
    expect(
      weekCarouselScrollOffsetForDayIndex(dayIndex: 1, columnWidth: 120),
      0,
    );
    expect(
      weekCarouselScrollOffsetForDayIndex(dayIndex: 6, columnWidth: 120),
      600,
    );
  });

  test('snapWeekCarouselOffset aligns to column width', () {
    expect(
      snapWeekCarouselOffset(
        offset: 105,
        columnWidth: 120,
        minExtent: 0,
        maxExtent: 960,
      ),
      120,
    );
    expect(
      snapWeekCarouselOffset(
        offset: 55,
        columnWidth: 120,
        minExtent: 0,
        maxExtent: 960,
      ),
      0,
    );
    expect(
      snapWeekCarouselOffset(
        offset: 950,
        columnWidth: 120,
        minExtent: 0,
        maxExtent: 960,
      ),
      960,
    );
  });

  test(
    'weekCarouselWindowDates is a continuous day strip around selection',
    () {
      final selected = DateTime(2026, 6, 17);
      final start = weekCarouselWindowStartFor(selected);
      final dates = weekCarouselWindowDates(windowStart: start);

      expect(
        dates.length,
        7 * (weekCarouselWindowWeeksBehind + 1 + weekCarouselWindowWeeksAhead),
      );
      expect(start, DateTime(2026, 4, 20));
      expect(dates.first, start);
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].difference(dates[i - 1]).inDays, 1);
      }

      final lanes = weekCarouselLanes(dates: dates, selectedDate: selected);
      final active = lanes
          .where((lane) => !lane.ghost)
          .map((lane) => lane.date);
      expect(active, [
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 16),
        DateTime(2026, 6, 17),
        DateTime(2026, 6, 18),
        DateTime(2026, 6, 19),
        DateTime(2026, 6, 20),
        DateTime(2026, 6, 21),
      ]);
    },
  );

  test(
    'week date header matches list badge and stays within month cell height',
    () {
      expect(
        CalendarDayBadgeLayout.weekStripHeightFromViewport(360),
        CalendarDayBadgeLayout.defaultSize,
      );
      expect(
        CalendarDayBadgeLayout.weekStripHeightFromViewport(360),
        lessThanOrEqualTo(DateCellLayout.cellSide(360)),
      );
      expect(
        CalendarDayBadgeLayout.weekStripHeightFromViewport(280),
        DateCellLayout.cellSide(280),
      );
      expect(
        CalendarDayBadgeLayout.weekStripHeightFromViewport(1200),
        CalendarDayBadgeLayout.defaultSize,
      );
    },
  );

  test('weekCarouselColumnWidth fits three days in the viewport', () {
    expect(DateCellLayout.weekCarouselColumnWidth(360), 120);
    expect(
      DateCellLayout.weekCarouselVisibleDays *
          DateCellLayout.weekCarouselColumnWidth(360),
      360,
    );
  });

  test('centering a day shows yesterday, today and tomorrow', () {
    final today = DateTime(2026, 9, 18);
    expect(weekCarouselVisibleDatesAround(today), [
      DateTime(2026, 9, 17),
      DateTime(2026, 9, 18),
      DateTime(2026, 9, 19),
    ]);
    expect(
      weekCarouselDayIndexForScrollOffset(
        offset: weekCarouselScrollOffsetForDayIndex(
          dayIndex: 10,
          columnWidth: 120,
        ),
        columnWidth: 120,
        dayCount: 21,
      ),
      10,
    );
  });

  test('weekCarouselSnapSpring is critically damped (no bounce)', () {
    final spring = weekCarouselSnapSpring;
    final critical = 2 * math.sqrt(spring.mass * spring.stiffness);
    expect(spring.damping, greaterThanOrEqualTo(critical * 0.98));
    expect(spring.damping, lessThan(critical * 1.2));
  });

  test('weekCarouselAttractDuration scales with travel distance', () {
    final onePage = weekCarouselAttractDuration(
      distance: 120,
      columnWidth: 120,
    );
    final twoPages = weekCarouselAttractDuration(
      distance: 240,
      columnWidth: 120,
    );
    expect(onePage.inMilliseconds, greaterThanOrEqualTo(260));
    expect(onePage.inMilliseconds, AlmanacDurations.snap.inMilliseconds);
    expect(twoPages.inMilliseconds, greaterThan(onePage.inMilliseconds));
    expect(twoPages.inMilliseconds, lessThanOrEqualTo(520));
  });
}
