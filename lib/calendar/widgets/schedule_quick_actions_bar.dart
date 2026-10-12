import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_fit_text.dart';
import '../../core/ui/almanac_tappable.dart';
import '../calendar_entry_capabilities.dart';
import '../calendar_types.dart';
import '../shift_quick_actions.dart';

typedef ShiftQuickActionCallback =
    Future<void> Function(AppEvent event, ShiftQuickAction action);

/// Кнопки «пропустить / вернуть смену» и «+30 мин сверхурочных».
///
/// Столбиком на всю ширину, зона нажатия 48 dp — не перехватывается карточкой.
class ScheduleQuickActionsBar extends StatelessWidget {
  const ScheduleQuickActionsBar({
    super.key,
    required this.event,
    required this.onAction,
    this.dense = false,
  });

  final AppEvent event;
  final ShiftQuickActionCallback onAction;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (!event.capabilities.editsCreateScheduleOverride) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final skipped = event.shiftSkipped;
    final gap = dense ? 6.0 : AlmanacSpacing.xxs;

    return Padding(
      padding: dense
          ? const EdgeInsets.only(top: 6)
          : const EdgeInsets.fromLTRB(
              AlmanacSpacing.sm,
              AlmanacSpacing.xxs,
              AlmanacSpacing.sm,
              AlmanacSpacing.xs,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ShiftActionButton(
            icon: skipped ? Icons.play_arrow_rounded : Icons.block_outlined,
            label: skipped
                ? (dense ? l10n.shiftQuickUnskipCompact : l10n.shiftQuickUnskip)
                : (dense ? l10n.shiftQuickSkipCompact : l10n.shiftQuickSkip),
            color: skipped ? scheme.primary : context.almanacColors.danger,
            onPressed: () => onAction(event, ShiftQuickAction.toggleSkip),
          ),
          if (!skipped) ...[
            SizedBox(height: gap),
            _ShiftActionButton(
              icon: Icons.more_time_outlined,
              label: dense
                  ? l10n.shiftQuickOvertimeCompact
                  : l10n.shiftQuickAddOvertime30,
              color: scheme.secondary,
              onPressed: () => onAction(event, ShiftQuickAction.addOvertime30),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftActionButton extends StatelessWidget {
  const _ShiftActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AlmanacTappable(
      onTap: onPressed,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: AlmanacFitText(
              text: label,
              style:
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ) ??
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
