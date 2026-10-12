import 'package:flutter/material.dart';
import '../../../data/holidays/russian_holidays.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';
import 'event_day_markers.dart';

/// Единый размер ячеек дат во всех видах календаря.
class DateCellLayout {
  DateCellLayout._();

  static const double minCellSide = 44;
  static const double maxCellSide = 56;

  /// Сколько дней показывает недельная карусель на узких экранах.
  static const int weekCarouselVisibleDays = 3;

  /// Ширина одной колонки (совпадает с [WeekdayHeader]).
  static double columnWidth(double viewportWidth) => viewportWidth / 7;

  /// Высота строки ячеек (квадрат на узких экранах, ограничена сверху).
  static double cellSide(double viewportWidth) {
    return columnWidth(viewportWidth).clamp(minCellSide, maxCellSide);
  }

  static bool isCompact(double viewportWidth) {
    return AlmanacBreakpoints.isMobile(viewportWidth) ||
        columnWidth(viewportWidth) < 48;
  }

  /// Включать ли недельную карусель: все 7 узких колонок не помещаются с запасом.
  static bool useWeekCarousel(double viewportWidth) {
    return isCompact(viewportWidth);
  }

  /// Ширина одной колонки в режиме карусели (видно [weekCarouselVisibleDays]).
  static double weekCarouselColumnWidth(double viewportWidth) {
    if (viewportWidth <= 0) return minCellSide;
    return viewportWidth / weekCarouselVisibleDays;
  }
}

/// Ячейка даты: мягкий фон, обводка «сегодня»/выбора и маркеры событий.
class DateCell extends StatelessWidget {
  const DateCell({
    super.key,
    required this.date,
    required this.onTap,
    this.onLongPress,
    this.inFocusedMonth = true,
    this.selected = false,
    this.events = const [],
    this.showWeekday = false,
    this.compact = false,
    this.activeProfileId,
    this.holiday,
    this.colorFilterActive = false,
    this.matchesColorFilter = true,
  });

  final DateTime date;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool inFocusedMonth;
  final bool selected;
  final bool showWeekday;
  final bool compact;
  final List<AppEvent> events;
  final String? activeProfileId;
  final RussianHoliday? holiday;
  final bool colorFilterActive;
  final bool matchesColorFilter;

  List<AppEvent> get _orderedEvents {
    if (activeProfileId == null || events.isEmpty) return events;
    return prioritizeEventsForProfile(events, activeProfileId!);
  }

  bool get hasEvents => events.isNotEmpty;
  bool get isWeekend =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static const int _maxMarkers = 3;

  /// Высота нижней полосы маркеров — одинакова у всех ячеек сетки.
  static double markersBandHeight(bool compact) {
    return eventDayMarkersBandHeight(
      compact: compact,
      style: EventDayMarkerStyle.dots,
      maxVisible: _maxMarkers,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final almanac = context.almanacColors;
    final radius = compact ? AlmanacRadius.sm : AlmanacRadius.md;
    final dimmed = colorFilterActive && hasEvents && !matchesColorFilter;

    final highlight = context.profileHighlight;
    final backgroundColor = _cellBackground(colorScheme, almanac, highlight);
    final markersHeight = markersBandHeight(compact);
    final borderWidth = 1.5;

    return SizedBox.expand(
      child: RepaintBoundary(
        child: Opacity(
          opacity: dimmed ? 0.38 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(radius),
              splashColor: highlight.accentEnd.withValues(alpha: 0.12),
              highlightColor: highlight.accentStart.withValues(alpha: 0.08),
              child: Padding(
                padding: EdgeInsets.all(compact ? 1.0 : 2.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: isToday
                          ? highlight.accentEnd
                          : selected
                          ? highlight.accentEnd.withValues(alpha: 0.45)
                          : Colors.transparent,
                      width: isToday ? 2 : borderWidth,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 2 : AlmanacSpacing.xxs,
                      vertical: compact ? 2 : AlmanacSpacing.xxs,
                    ),
                    child: LayoutBuilder(
                      builder: (context, cellConstraints) {
                        final showMarkers =
                            cellConstraints.maxHeight >= markersHeight + 8;
                        return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: _DayNumberBadge(
                                  day: date.day,
                                  selected: selected,
                                  inFocusedMonth: inFocusedMonth,
                                  isWeekend: isWeekend,
                                  isToday: isToday,
                                  compact: compact,
                                  highlightColor: highlight.accentEnd,
                                  colorScheme: colorScheme,
                                  weekendColor: almanac.weekend,
                                  mutedColor: almanac.muted,
                                ),
                              ),
                            ),
                            if (showMarkers)
                              SizedBox(
                                height: markersHeight,
                                child: hasEvents && inFocusedMonth
                                    ? Align(
                                        alignment: Alignment.bottomCenter,
                                        child: EventDayMarkers(
                                          events: _orderedEvents,
                                          compact: compact,
                                          selected: selected,
                                          activeProfileId: activeProfileId,
                                          maxVisible: _maxMarkers,
                                          showOverflowCount: true,
                                          style: EventDayMarkerStyle.dots,
                                        ),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                        if (holiday != null && inFocusedMonth && !compact)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Tooltip(
                              message: holiday!.name,
                              child: Icon(
                                Icons.circle,
                                size: 5,
                                color: almanac.weekend.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                      ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _cellBackground(
    ColorScheme colorScheme,
    AlmanacColors almanac,
    ProfileHighlightColors highlight,
  ) {
    if (!inFocusedMonth) return Colors.transparent;

    if (hasEvents) {
      return eventDayBackgroundTint(
        events: events,
        colorScheme: colorScheme,
        selected: selected,
        inFocusedMonth: inFocusedMonth,
        activeProfileId: activeProfileId,
        selectionColor: highlight.accentEnd,
      );
    }

    if (isWeekend) {
      return almanac.weekend.withValues(alpha: 0.06);
    }

    if (selected) {
      return highlight.accentEnd.withValues(alpha: 0.1);
    }

    return colorScheme.surfaceContainerHighest.withValues(alpha: 0.22);
  }
}

class _DayNumberBadge extends StatelessWidget {
  const _DayNumberBadge({
    required this.day,
    required this.selected,
    required this.inFocusedMonth,
    required this.isWeekend,
    required this.isToday,
    required this.compact,
    required this.highlightColor,
    required this.colorScheme,
    required this.weekendColor,
    required this.mutedColor,
  });

  final int day;
  final bool selected;
  final bool inFocusedMonth;
  final bool isWeekend;
  final bool isToday;
  final bool compact;
  final Color highlightColor;
  final ColorScheme colorScheme;
  final Color weekendColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final textColor = selected || isToday
        ? highlightColor
        : !inFocusedMonth
        ? mutedColor.withValues(alpha: 0.55)
        : isWeekend
        ? weekendColor
        : colorScheme.onSurface;

    return Text(
      '$day',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: textColor,
        fontSize: compact ? 11 : 14,
        fontWeight: isToday || selected ? FontWeight.w800 : FontWeight.w600,
        height: 1,
      ),
    );
  }
}
