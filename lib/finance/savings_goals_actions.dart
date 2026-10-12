part of 'savings_goals_sheet.dart';

mixin _SavingsGoalsActions on ConsumerState<SavingsGoalsSheet> {
  void _reload() {
    _normalizeStoredGoals();
    ref.read(savingsGoalsVersionProvider.notifier).state++;
    setState(() {});
  }

  void _normalizeStoredGoals() {
    final repo = ref.read(savingsGoalRepositoryProvider);
    final active = ref.read(activeProfileNotifierProvider);
    for (final goal in repo.getForProfile(active.id)) {
      if (goal.colorValue != null) continue;
      repo.update(
        profileId: active.id,
        goal: goal.copyWith(colorValue: defaultSavingsGoalColorValue),
      );
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  Future<void> _deleteGoal(BuildContext context, SavingsGoal goal) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.deleteSavingsGoalTitle,
      message: l10n.deleteSavingsGoalConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteEvent,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    ref
        .read(savingsGoalRepositoryProvider)
        .delete(profileId: goal.profileId, goalId: goal.id);
    _reload();
    if (context.mounted) {
      AlmanacFeedback.showSuccess(context, l10n.savingsGoalDeleted);
    }
  }

  Future<void> _openForm(BuildContext context, {SavingsGoal? existing}) async {
    await SavingsGoalsSheet.openGoalForm(
      context,
      ref,
      existing: existing,
      placement: widget.placement,
    );
    _reload();
  }
}
