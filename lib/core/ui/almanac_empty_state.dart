import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Пустое состояние списка: иконка, текст и опциональная кнопка.
class AlmanacEmptyState extends StatelessWidget {
  const AlmanacEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.event_busy_outlined,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AlmanacSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
              ),
              AlmanacGap.sm,
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.almanacColors.muted,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                AlmanacGap.md,
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
