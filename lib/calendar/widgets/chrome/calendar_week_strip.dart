import 'package:flutter/material.dart';
import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import 'calendar_date_row.dart';
import 'calendar_day_badge.dart';
import 'date_cell.dart';
import '../week/week_carousel_lane.dart';

/// Горизонтальная полоска из 7 ячеек дат.
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.weekDates,
    required this.selectedDate,
    required this.eventsIndex,
    required this.onDateSelected,
    required this.activeProfileId,
    required this.viewportWidth,
    this.onDateLongPress,
    this.compact,
    this.inFocusedMonthFor,
    this.colorFilter = const {},
    this.columnWidth,
    this.controller,
  });

  final List<DateTime> weekDates;
  final DateTime selectedDate;
  final Map<DateTime, List<AppEvent>> eventsIndex;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;
  final String activeProfileId;
  final double viewportWidth;
  final bool? compact;
  final bool Function(DateTime date)? inFocusedMonthFor;
  final Set<int> colorFilter;

  /// Фиксированная ширина ячейки в режиме карусели (иначе — 1/7 ширины).
  final double? columnWidth;

  /// Контроллер горизонтальной прокрутки карусели (синхрон с сеткой событий).
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final isCompact = compact ?? DateCellLayout.isCompact(viewportWidth);
    final width = columnWidth;
    final stripHeight = CalendarDayBadgeLayout.weekStripHeightFromViewport(
      viewportWidth,
    );

    Widget buildBadge(DateTime date) {
      return CalendarDayBadge(
        key: ValueKey('strip-${date.toIso8601String()}'),
        date: date,
        selected: isSameCalendarDay(date, selectedDate),
        onTap: () => onDateSelected(date),
        onLongPress: onDateLongPress == null
            ? null
            : () => onDateLongPress!(date),
        expandToWidth: true,
      );
    }

    if (width != null) {
      return SizedBox(
        height: stripHeight,
        child: WeekCarouselLane(
          columnWidth: width,
          dayCount: weekDates.length,
          visibleDays: DateCellLayout.weekCarouselVisibleDays,
          viewportWidth: viewportWidth,
          controller: controller,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          childBuilder: (index) => buildBadge(weekDates[index]),
        ),
      );
    }

    return CalendarDateRow(
      compact: isCompact,
      useBadgeHeight: true,
      children: weekDates.map(buildBadge).toList(),
    );
  }
}
