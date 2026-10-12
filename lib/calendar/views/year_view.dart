import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../state/calendar_filter_providers.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_card.dart';
import '../../core/ui/almanac_scroll.dart';
import '../calendar_event_index.dart';
import '../calendar_month_grid.dart';
import '../calendar_types.dart';
import '../widgets/chrome/event_day_markers.dart';

/// Годовой вид: обзор года и 12 мини-календарей.
class YearCalendarView extends StatelessWidget {
  const YearCalendarView({
    super.key,
    required this.focusedMonth,
    required this.events,
    required this.onMonthSelected,
    required this.activeProfileId,
    this.colorFilter = const {},
  });

  final DateTime focusedMonth;
  final List<AppEvent> events;
  final ValueChanged<DateTime> onMonthSelected;
  final String activeProfileId;
  final Set<int> colorFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final year = focusedMonth.year;
    final eventsIndex = indexEventsByDay(events);
    final monthCounts = _eventCountByMonth(events, year);
    final activeMonths = monthCounts.values.where((count) => count > 0).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final highlight = context.profileHighlight;
        final columns = AlmanacBreakpoints.yearViewColumns(
          constraints.maxWidth,
        );
        const spacing = AlmanacSpacing.sm;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final now = DateTime.now();
        final currentMonth = now.year == year ? now.month : null;

        return CustomScrollView(
          cacheExtent: AlmanacScroll.calendarCacheExtent,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
                    child: AlmanacCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_view_month_outlined,
                            color: highlight.accentEnd,
                          ),
                          const SizedBox(width: AlmanacSpacing.sm),
                          Expanded(
                            child: Text(
                              l10n.yearSummary(events.length, activeMonths),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$year',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(12, (index) {
                      final month = index + 1;
                      final monthDate = DateTime(year, month, 1);
                      final eventCount = monthCounts[month] ?? 0;

                      return SizedBox(
                        width: cardWidth,
                        child: RepaintBoundary(
                          child: _YearMonthCard(
                            month: month,
                            year: year,
                            monthName: l10n.monthName(month),
                            eventCount: eventCount,
                            isCurrentMonth: month == currentMonth,
                            eventsIndex: eventsIndex,
                            activeProfileId: activeProfileId,
                            colorFilter: colorFilter,
                            onTap: () => onMonthSelected(monthDate),
                          ),
                        ),
                      );
                    }),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  static Map<int, int> _eventCountByMonth(List<AppEvent> events, int year) {
    final counts = {for (var month = 1; month <= 12; month++) month: 0};
    for (final event in events) {
      final date = event.start;
      if (date.year == year) {
        counts[date.month] = (counts[date.month] ?? 0) + 1;
      }
    }
    return counts;
  }
}

class _YearMonthCard extends StatelessWidget {
  const _YearMonthCard({
    required this.month,
    required this.year,
    required this.monthName,
    required this.eventCount,
    required this.isCurrentMonth,
    required this.eventsIndex,
    required this.activeProfileId,
    required this.colorFilter,
    required this.onTap,
  });

  final int month;
  final int year;
  final String monthName;
  final int eventCount;
  final bool isCurrentMonth;
  final Map<DateTime, List<AppEvent>> eventsIndex;
  final String activeProfileId;
  final Set<int> colorFilter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final highlight = context.profileHighlight;

    return AlmanacCard(
      elevated: false,
      bordered: false,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AlmanacSpacing.xs,
        AlmanacSpacing.sm,
        AlmanacSpacing.xs,
        AlmanacSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (isCurrentMonth)
                Flexible(
                  child: _HeaderChip(
                    label: l10n.currentMonthBadge,
                    color: context.profileHighlight.warmAccent,
                  ),
                ),
              if (eventCount > 0) ...[
                const SizedBox(width: AlmanacSpacing.xxs),
                Flexible(
                  child: _HeaderChip(
                    label: l10n.monthEventsBadge(eventCount),
                    color: highlight.accentEnd,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          _MiniWeekdayRow(),
          const SizedBox(height: AlmanacSpacing.xxs),
          _YearMiniGrid(
            month: month,
            year: year,
            eventsIndex: eventsIndex,
            activeProfileId: activeProfileId,
            colorFilter: colorFilter,
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AlmanacSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AlmanacRadius.chip,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _MiniWeekdayRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final almanac = context.almanacColors;

    return Row(
      children: List.generate(7, (index) {
        final weekday = DateTime.monday + index;
        final isWeekend =
            weekday == DateTime.saturday || weekday == DateTime.sunday;
        final label = l10n.shortWeekday(weekday);
        final letter = label.isNotEmpty ? label.substring(0, 1) : '?';

        return Expanded(
          child: Center(
            child: Text(
              letter.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w700,
                color: isWeekend
                    ? almanac.weekend.withValues(alpha: 0.85)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _YearMiniGrid extends StatelessWidget {
  const _YearMiniGrid({
    required this.month,
    required this.year,
    required this.eventsIndex,
    required this.activeProfileId,
    required this.colorFilter,
  });

  final int month;
  final int year;
  final Map<DateTime, List<AppEvent>> eventsIndex;
  final String activeProfileId;
  final Set<int> colorFilter;

  @override
  Widget build(BuildContext context) {
    final dates = monthGridDates(
      DateTime(year, month, 1),
      fixedWeekCount: yearMiniWeekCount,
    );
    const weekCount = yearMiniWeekCount;

    return AspectRatio(
      aspectRatio: 7 / weekCount,
      child: Column(
        children: List.generate(weekCount, (weekIndex) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: weekIndex > 0 ? 2 : 0),
              child: Row(
                children: List.generate(7, (dayIndex) {
                  final date = dates[weekIndex * 7 + dayIndex];
                  return Expanded(
                    child: _YearMiniCell(
                      date: date,
                      inFocusedMonth: date.month == month,
                      events: date.month == month
                          ? eventsForDay(eventsIndex, date)
                          : const <AppEvent>[],
                      activeProfileId: activeProfileId,
                      colorFilter: colorFilter,
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _YearMiniCell extends StatelessWidget {
  const _YearMiniCell({
    required this.date,
    required this.inFocusedMonth,
    required this.events,
    required this.activeProfileId,
    required this.colorFilter,
  });

  final DateTime date;
  final bool inFocusedMonth;
  final List<AppEvent> events;
  final String activeProfileId;
  final Set<int> colorFilter;

  bool get hasEvents => events.isNotEmpty;

  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final almanac = context.almanacColors;
    final highlight = context.profileHighlight;
    final visibleEvents = filterEventsByColor(events, colorFilter);

    if (!inFocusedMonth) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${date.day}',
            textScaler: TextScaler.noScaling,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 8,
              height: 1,
              color: almanac.muted.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    final background = visibleEvents.isNotEmpty
        ? eventDayBackgroundTint(
            events: visibleEvents,
            colorScheme: scheme,
            selected: false,
            inFocusedMonth: true,
            activeProfileId: activeProfileId,
            selectionColor: highlight.accentEnd,
            accentEnd: highlight.accentEnd,
          )
        : isWeekend
        ? almanac.weekend.withValues(alpha: 0.07)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.18);

    return Padding(
      padding: const EdgeInsets.all(0.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AlmanacRadius.xxs),
          border: isToday
              ? Border.all(color: highlight.accentEnd, width: 1.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AlmanacRadius.xxs),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MiniDayBadge(
                    day: date.day,
                    isToday: isToday,
                    isWeekend: isWeekend,
                  ),
                  if (visibleEvents.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    EventDayMarkers(
                      events: prioritizeEventsForProfile(
                        visibleEvents,
                        activeProfileId,
                      ),
                      activeProfileId: activeProfileId,
                      style: EventDayMarkerStyle.dots,
                      dense: true,
                      maxVisible: 2,
                      showOverflowCount: false,
                      showPlusWhenOverflow: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniDayBadge extends StatelessWidget {
  const _MiniDayBadge({
    required this.day,
    required this.isToday,
    required this.isWeekend,
  });

  final int day;
  final bool isToday;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final almanac = context.almanacColors;
    final highlight = context.profileHighlight;

    return Text(
      '$day',
      textScaler: TextScaler.noScaling,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 8,
        height: 1,
        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
        color: isToday
            ? highlight.accentEnd
            : isWeekend
            ? almanac.weekend
            : scheme.onSurface,
      ),
    );
  }
}
