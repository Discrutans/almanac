import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/profiles/context_profile.dart';
import '../../../finance/savings_calculator.dart';
import '../../../finance/savings_goal_types.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../finance/savings_goals_sheet.dart';
import '../../../state/app_providers.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_card.dart';
import '../../event_time_utils.dart';
import '../../month_statistics.dart';
import '../../../finance/pay_types.dart';
import '../../../finance/work_pay_calculator.dart';

part 'month_stats/month_statistics_content.dart';
part 'month_stats/month_statistics_widgets.dart';

/// Панель статистики под месячной сеткой (всегда развёрнута).
class MonthStatisticsPanel extends ConsumerWidget {
  const MonthStatisticsPanel({
    super.key,
    required this.focusedMonth,
    required this.stats,
    this.schedules = const [],
  });

  final DateTime focusedMonth;
  final MonthStatistics stats;
  final List<CyclicWorkSchedule> schedules;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    ref.watch(savingsGoalsVersionProvider);
    final active = ref.watch(activeProfileNotifierProvider);
    final goals = ref
        .read(savingsGoalRepositoryProvider)
        .getForProfile(active.id);
    final savingsPlans = computeSavingsPlans(
      goals: goals,
      monthlyNetIncome: stats.workPay.hasPayConfigured
          ? stats.workPay.totalPay
          : null,
    );

    return AlmanacCard(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AlmanacSpacing.xxs),
              child: Text(
                l10n.statsTitle(focusedMonth.month),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            _StatsContent(
              stats: stats,
              schedules: schedules,
              savingsPlans: savingsPlans,
              focusedMonth: focusedMonth,
              l10n: l10n,
              colorScheme: colorScheme,
              onManageSavingsGoals: () => SavingsGoalsSheet.show(context),
            ),
          ],
        ),
      ),
    );
  }
}
