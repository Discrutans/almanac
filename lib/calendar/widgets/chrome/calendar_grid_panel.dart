import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_card.dart';
import 'weekday_header.dart';

/// Frosted-панель с заголовком дней недели и содержимым сетки.
class CalendarGridPanel extends StatelessWidget {
  const CalendarGridPanel({
    super.key,
    required this.child,
    this.padding,
    this.expanded = false,
    this.showWeekdayHeader = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool expanded;
  final bool showWeekdayHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final panel = AlmanacCard(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AlmanacSpacing.xs,
            AlmanacSpacing.sm,
            AlmanacSpacing.xs,
            AlmanacSpacing.sm,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (showWeekdayHeader) ...[
            const WeekdayHeader(),
            Divider(
              height: AlmanacSpacing.md,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ],
          if (expanded) Expanded(child: child) else child,
        ],
      ),
    );

    return panel;
  }
}
