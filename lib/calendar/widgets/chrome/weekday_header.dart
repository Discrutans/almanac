import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';

/// Заголовки дней недели: Mon–Sun / Пн–Вс.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

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

        return Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.shortWeekday(weekday).toUpperCase(),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isWeekend
                      ? almanac.weekend.withValues(alpha: 0.9)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 10.5,
                  height: 1,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
