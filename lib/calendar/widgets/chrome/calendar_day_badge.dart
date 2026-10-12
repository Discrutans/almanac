import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_event_index.dart';
import 'date_cell.dart';

/// Размеры бейджа даты (как в списке / agenda).
class CalendarDayBadgeLayout {
  CalendarDayBadgeLayout._();

  static const double defaultSize = 46;

  static double badgeSize({required bool compact, double? columnWidth}) {
    if (!compact) return defaultSize;
    final width = columnWidth ?? defaultSize;
    return (width * 0.38).clamp(40.0, defaultSize);
  }

  /// Высота шапки дня в неделе — как бейдж в списке.
  static double weekStripHeightFromViewport(double viewportWidth) {
    final monthCell = DateCellLayout.cellSide(viewportWidth);
    return monthCell < defaultSize ? monthCell : defaultSize;
  }
}

/// Компактный бейдж даты: день недели сверху, число снизу (как в списке).
class CalendarDayBadge extends StatelessWidget {
  const CalendarDayBadge({
    super.key,
    required this.date,
    required this.selected,
    this.onTap,
    this.onLongPress,
    this.size = CalendarDayBadgeLayout.defaultSize,
    this.expandToWidth = false,
    this.interactive = true,
    this.highlightToday = true,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double size;
  final bool expandToWidth;
  final bool interactive;
  final bool highlightToday;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final highlight = context.profileHighlight;
    final almanac = context.almanacColors;
    final isToday = isSameCalendarDay(date, DateTime.now());
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final accent = selected ? highlight.accentEnd : scheme.onSurface;
    final showToday = highlightToday && isToday;
    final weekdayFontSize = size <= 42 ? 9.0 : 10.0;
    final double? dayFontSize = size <= 42 ? 15.0 : null;
    final borderRadius = AlmanacRadius.control;
    final borderColor = showToday
        ? highlight.accentEnd
        : selected
        ? highlight.accentEnd
        : scheme.outlineVariant.withValues(alpha: 0.35);
    final borderWidth = showToday ? 2.0 : (selected ? 1.5 : 1.0);

    Widget badgeBody = Container(
      width: expandToWidth ? double.infinity : size,
      height: expandToWidth ? double.infinity : size,
      margin: expandToWidth ? EdgeInsets.zero : null,
      decoration: BoxDecoration(
        color: selected
            ? highlight.accentEnd.withValues(alpha: 0.14)
            : showToday
            ? highlight.accentEnd.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: showToday && !selected
            ? [
                BoxShadow(
                  color: highlight.accentEnd.withValues(alpha: 0.16),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.shortWeekday(date.weekday).toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: weekdayFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              height: 1.1,
              color: isWeekend
                  ? almanac.weekend.withValues(alpha: 0.95)
                  : scheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${date.day}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1,
              fontSize: dayFontSize,
              color: accent,
            ),
          ),
        ],
      ),
    );

    if (expandToWidth) {
      badgeBody = SizedBox.expand(child: badgeBody);
    }

    if (!interactive || onTap == null) return badgeBody;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        splashColor: highlight.accentEnd.withValues(alpha: 0.12),
        highlightColor: highlight.accentStart.withValues(alpha: 0.08),
        child: badgeBody,
      ),
    );
  }
}
