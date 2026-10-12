import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/holidays/russian_holidays.dart';
import '../../data/profiles/context_profile.dart';
import '../../state/calendar_filter_providers.dart';
import '../../core/theme/almanac_tokens.dart';
import '../calendar_event_index.dart';
import '../calendar_month_grid.dart';
import '../calendar_types.dart';
import '../month_statistics.dart';
import '../widgets/chrome/calendar_date_row.dart';
import '../widgets/chrome/calendar_grid_panel.dart';
import '../widgets/chrome/date_cell.dart';
import '../widgets/chrome/month_statistics_panel.dart';

/// Месячный вид: frosted-сетка фиксированной высоты и статистика снизу.
class MonthCalendarView extends StatelessWidget {
  const MonthCalendarView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    this.onDateLongPress,
    required this.activeProfileId,
    this.schedules = const [],
    this.colorFilter = const {},
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<AppEvent> events;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;
  final String activeProfileId;
  final List<CyclicWorkSchedule> schedules;
  final Set<int> colorFilter;

  static const _weekdayHeaderHeight = 18.0;
  static const _minStatsHeight = 80.0;

  static double _chromeHeightFor(BuildContext context) {
    final weekdayHeight = MediaQuery.textScalerOf(
      context,
    ).scale(_weekdayHeaderHeight);
    return AlmanacSpacing.sm * 2 + weekdayHeight + AlmanacSpacing.md;
  }

  @override
  Widget build(BuildContext context) {
    final dates = monthGridDates(focusedMonth);
    final eventsIndex = indexEventsByDay(events);
    final stats = computeMonthStatistics(
      focusedMonth: focusedMonth,
      events: events,
      schedules: schedules,
    );
    final filterActive = colorFilter.isNotEmpty;
    final weekRows = _weekRows(dates);

    return LayoutBuilder(
      builder: (context, constraints) {
        final weekCount = weekRows.length;
        const gridHorizontalPad = AlmanacSpacing.xs * 2;
        final gridInnerWidth = constraints.maxWidth - gridHorizontalPad;
        final rowHeight = DateCellLayout.cellSide(gridInnerWidth);
        final gridBodyHeight =
            rowHeight * weekCount + math.max(0, weekCount - 1).toDouble();
        final chromeHeight = _chromeHeightFor(context);
        final naturalGridHeight = chromeHeight + gridBodyHeight;
        final showStats =
            constraints.maxHeight >= naturalGridHeight + _minStatsHeight;
        final isCompact = DateCellLayout.isCompact(constraints.maxWidth);
        final scheme = Theme.of(context).colorScheme;
        final weeks = _weeksColumn(
          weekRows: weekRows,
          eventsIndex: eventsIndex,
          filterActive: filterActive,
          isCompact: isCompact,
          scheme: scheme,
          expandRows: !showStats,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showStats)
              SizedBox(
                height: naturalGridHeight,
                child: CalendarGridPanel(child: weeks),
              )
            else
              Expanded(child: CalendarGridPanel(expanded: true, child: weeks)),
            if (showStats) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              Expanded(
                child: MonthStatisticsPanel(
                  focusedMonth: focusedMonth,
                  stats: stats,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _weeksColumn({
    required List<List<DateTime>> weekRows,
    required Map<DateTime, List<AppEvent>> eventsIndex,
    required bool filterActive,
    required bool isCompact,
    required ColorScheme scheme,
    required bool expandRows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var weekIndex = 0; weekIndex < weekRows.length; weekIndex++) ...[
          if (weekIndex > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.18),
            ),
          _maybeExpandRow(
            expand: expandRows,
            child: RepaintBoundary(
              child: CalendarDateRow(
                children: weekRows[weekIndex].map((date) {
                  final dayEvents = eventsForDay(eventsIndex, date);
                  final visibleEvents = filterActive
                      ? filterEventsByColor(dayEvents, colorFilter)
                      : dayEvents;
                  return DateCell(
                    key: ValueKey('month-${date.toIso8601String()}'),
                    date: date,
                    selected: isSameCalendarDay(date, selectedDate),
                    inFocusedMonth: _sameMonth(date, focusedMonth),
                    events: visibleEvents,
                    activeProfileId: activeProfileId,
                    holiday: RussianHolidays.onDate(date),
                    compact: isCompact,
                    onTap: () => onDateSelected(date),
                    onLongPress: onDateLongPress == null
                        ? null
                        : () => onDateLongPress!(date),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Widget _maybeExpandRow({required bool expand, required Widget child}) {
    return expand ? Expanded(child: child) : child;
  }

  static List<List<DateTime>> _weekRows(List<DateTime> dates) {
    final rows = <List<DateTime>>[];
    for (var i = 0; i < dates.length; i += 7) {
      rows.add(dates.sublist(i, i + 7));
    }
    return rows;
  }

  static bool _sameMonth(DateTime left, DateTime right) {
    return left.year == right.year && left.month == right.month;
  }
}
