import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../calendar/event_time_utils.dart';
import '../calendar/widgets/chrome/almanac_mini_color_picker.dart';
import 'savings_calculator.dart';
import 'savings_goal_calendar_projection.dart';
import 'savings_goal_types.dart';
import '../core/localization/app_localizations.dart';
import '../state/app_providers.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_buttons.dart';
import '../core/ui/almanac_feedback.dart';

part 'savings_goals_list.dart';
part 'savings_goals_editor.dart';
part 'savings_goals_actions.dart';

/// Управление целями накопления активного профиля.
class SavingsGoalsSheet extends ConsumerStatefulWidget {
  const SavingsGoalsSheet({
    super.key,
    this.placement = AlmanacSheetPlacement.top,
  });

  final AlmanacSheetPlacement placement;

  static Future<void> show(
    BuildContext context, {
    AlmanacSheetPlacement placement = AlmanacSheetPlacement.top,
  }) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      placement: placement,
      title: l10n.savingsGoalsTitle,
      child: SavingsGoalsSheet(placement: placement),
    );
  }

  /// Открывает форму цели (из списка целей или с календаря).
  static Future<void> openGoalForm(
    BuildContext context,
    WidgetRef ref, {
    SavingsGoal? existing,
    AlmanacSheetPlacement placement = AlmanacSheetPlacement.top,
  }) async {
    final active = ref.read(activeProfileNotifierProvider);
    final repo = ref.read(savingsGoalRepositoryProvider);
    final l10n = AppLocalizations.of(context);

    await showAlmanacSheet<void>(
      context: context,
      placement: placement,
      title: existing == null
          ? l10n.newSavingsGoalTitle
          : l10n.editSavingsGoalTitle,
      child: _SavingsGoalFormDialog(
        existing: existing,
        onPersist: (result) async {
          final goal = SavingsGoal(
            id: existing?.id ?? 'goal-${DateTime.now().microsecondsSinceEpoch}',
            profileId: active.id,
            title: result.title,
            targetAmount: result.targetAmount,
            targetDate: result.targetDate,
            note: result.note,
            monthlyLivingExpenses: result.monthlyLivingExpenses,
            savedAmount: result.savedAmount,
            colorValue: result.colorValue,
            createdAt: existing?.createdAt ?? DateTime.now(),
          );

          if (existing == null) {
            repo.add(goal);
          } else {
            repo.update(profileId: active.id, goal: goal);
          }
          ref.read(savingsGoalsVersionProvider.notifier).state++;
        },
      ),
    );
  }

  @override
  ConsumerState<SavingsGoalsSheet> createState() => _SavingsGoalsSheetState();
}
