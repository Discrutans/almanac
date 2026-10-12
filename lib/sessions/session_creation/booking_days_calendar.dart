import 'package:flutter/material.dart';
import '../../calendar/calendar_event_index.dart';
import '../../calendar/calendar_month_grid.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/almanac_tokens.dart';

class BookingDaysCalendar extends StatelessWidget {
  const BookingDaysCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDates,
    required this.onToggleDate,
    required this.onPrevMonth,
    required this.onNextMonth,
    this.compact = false,
  });

  final DateTime focusedMonth;
  final Set<DateTime> selectedDates;
  final ValueChanged<DateTime> onToggleDate;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final today = calendarDayKey(DateTime.now());
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final dates = monthGridDates(monthStart);
    final weekCount = dates.length ~/ 7;
    final canGoBack =
        focusedMonth.year > today.year ||
        (focusedMonth.year == today.year && focusedMonth.month > today.month);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: compact ? 20 : 24,
              tooltip: l10n.month,
              onPressed: canGoBack ? onPrevMonth : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                l10n.monthYear(focusedMonth.month, focusedMonth.year),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 13 : null,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: compact ? 20 : 24,
              tooltip: l10n.month,
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!compact) const SizedBox(height: AlmanacSpacing.xs),
        Row(
          children: [
            for (final day in const [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
              DateTime.saturday,
              DateTime.sunday,
            ])
              Expanded(
                child: Text(
                  l10n.weekdayShort(day),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 10 : null,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 2 : AlmanacSpacing.xs),
        for (var week = 0; week < weekCount; week++)
          Padding(
            padding: EdgeInsets.only(top: week > 0 ? (compact ? 0 : 2) : 0),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _DayCell(
                      date: dates[week * 7 + i],
                      inMonth: dates[week * 7 + i].month == focusedMonth.month,
                      selected: selectedDates.contains(dates[week * 7 + i]),
                      today: dates[week * 7 + i] == today,
                      enabled: !dates[week * 7 + i].isBefore(today),
                      compact: compact,
                      onTap: () => onToggleDate(dates[week * 7 + i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final DateTime date;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faded = !inMonth || !enabled;
    Color? fill;
    Color textColor = faded
        ? scheme.onSurface.withValues(alpha: 0.28)
        : scheme.onSurface;
    if (selected && inMonth) {
      fill = scheme.primary;
      textColor = scheme.onPrimary;
    }

    return Padding(
      padding: EdgeInsets.all(compact ? 0.5 : 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: inMonth && enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            height: compact ? 28 : 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: today && !selected
                    ? Border.all(color: scheme.primary)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontSize: compact ? 11 : null,
                    fontWeight: selected || today
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
