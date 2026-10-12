part of '../month_statistics_panel.dart';

Widget _fitChipWidth({required Widget child}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width.isFinite && width > 0 ? width : 240,
        ),
        child: child,
      );
    },
  );
}

class _SavingsGoalStats extends StatelessWidget {
  const _SavingsGoalStats({required this.plan, required this.l10n});

  final SavingsPlanSummary plan;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final goal = plan.goal;
    final surplus = plan.surplusAfterBudget;
    final metrics = <_StatMetric>[
      _StatMetric(
        icon: Icons.savings_outlined,
        label: l10n.savingsGoalStatMonthly(
          formatMoney(plan.monthlySavingsNeeded),
        ),
        value: plan.isOverdue
            ? l10n.savingsGoalOverdueHint
            : l10n.savingsGoalDaysLeft(plan.daysRemaining),
      ),
    ];

    if (plan.monthlyLivingExpenses > 0) {
      metrics.add(
        _StatMetric(
          icon: Icons.receipt_long_outlined,
          label: l10n.savingsGoalStatBudget(
            formatMoney(plan.totalMonthlyBudget),
          ),
          value: formatMoney(plan.monthlyLivingExpenses),
        ),
      );
    }

    if (surplus != null) {
      metrics.add(
        _StatMetric(
          icon: surplus >= 0
              ? Icons.trending_up_outlined
              : Icons.trending_down_outlined,
          label: surplus >= 0
              ? l10n.savingsGoalStatSurplus('')
              : l10n.savingsGoalStatDeficit(''),
          value: surplus >= 0
              ? '+${formatMoney(surplus)}'
              : '−${formatMoney(surplus.abs())}',
        ),
      );
    }

    return _UnifiedStatGroup(
      title: goal.title,
      subtitle: formatMoney(goal.targetAmount),
      titleIcon: Icons.savings_outlined,
      accentColor: Color(goal.effectiveColorValue),
      metrics: metrics,
    );
  }
}

class _StatMetric {
  const _StatMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _UnifiedStatGroup extends StatelessWidget {
  const _UnifiedStatGroup({
    required this.metrics,
    this.title,
    this.subtitle,
    this.titleIcon,
    this.accentColor,
    this.detailLines,
    this.detailTitle,
  });

  final List<_StatMetric> metrics;
  final String? title;
  final String? subtitle;
  final IconData? titleIcon;
  final Color? accentColor;
  final List<String>? detailLines;
  final String? detailTitle;

  @override
  Widget build(BuildContext context) {
    final visibleMetrics = metrics;
    final lines = detailLines?.where((line) => line.isNotEmpty).toList() ?? [];
    if (visibleMetrics.isEmpty && lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AlmanacSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
            colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: AlmanacRadius.chip,
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: AlmanacElevation.subtleShadow(colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      titleIcon ?? Icons.flag_outlined,
                      size: 15,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: AlmanacSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (visibleMetrics.isNotEmpty || lines.isNotEmpty)
              const SizedBox(height: AlmanacSpacing.sm),
          ],
          if (visibleMetrics.isNotEmpty)
            Wrap(
              spacing: AlmanacSpacing.md,
              runSpacing: AlmanacSpacing.sm,
              children: [
                for (final metric in visibleMetrics)
                  _InlineStatMetric(metric: metric, accent: accent),
              ],
            ),
          if (lines.isNotEmpty) ...[
            if (visibleMetrics.isNotEmpty) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              Divider(height: 1, color: accent.withValues(alpha: 0.12)),
              const SizedBox(height: AlmanacSpacing.sm),
            ],
            Text(
              detailTitle ?? AppLocalizations.of(context).paySummaryDetails,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xxs),
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Text(
                lines[i],
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InlineStatMetric extends StatelessWidget {
  const _InlineStatMetric({required this.metric, required this.accent});

  final _StatMetric metric;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _fitChipWidth(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(metric.icon, size: 15, color: accent),
            ),
          ),
          const SizedBox(width: AlmanacSpacing.xs),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _fitChipWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AlmanacSpacing.sm,
          vertical: AlmanacSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: AlmanacRadius.chip,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: AlmanacElevation.subtleShadow(colorScheme),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 15, color: colorScheme.primary),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCategoryChip extends StatelessWidget {
  const _StatCategoryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    this.countText,
  });

  final IconData icon;
  final String label;
  final int value;
  final int total;
  final Color color;
  final String? countText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : value / total;

    return _fitChipWidth(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AlmanacSpacing.sm,
          vertical: AlmanacSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
              colorScheme.surfaceContainerLow.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: AlmanacRadius.chip,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: AlmanacElevation.subtleShadow(colorScheme),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AlmanacRadius.control,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 15, color: color),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    countText ?? '$value',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 72,
                    child: ClipRRect(
                      borderRadius: AlmanacRadius.chip,
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 3,
                        color: color,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
