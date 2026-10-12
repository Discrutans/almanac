part of 'savings_goals_sheet.dart';

class _SavingsGoalsSheetState extends ConsumerState<SavingsGoalsSheet>
    with _SavingsGoalsActions {
  @override
  Widget build(BuildContext context) {
    ref.watch(savingsGoalsVersionProvider);
    final active = ref.watch(activeProfileNotifierProvider);
    final repo = ref.read(savingsGoalRepositoryProvider);
    final goals = repo.getForProfile(active.id);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.savingsGoalsProfileHint(active.name),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AlmanacSpacing.lg),
            child: Text(
              l10n.savingsGoalsEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: goals.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final goal = goals[index];
              final plan = computeSavingsPlan(goal: goal);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(goal.title),
                subtitle: Text(
                  l10n.savingsGoalListSubtitle(
                    formatMoney(goal.targetAmount),
                    _formatDate(context, goal.targetDate),
                    formatMoney(plan.monthlySavingsNeeded),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openForm(context, existing: goal),
                    ),
                    IconButton(
                      tooltip: l10n.deleteEvent,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteGoal(context, goal),
                    ),
                  ],
                ),
                onTap: () => _openForm(context, existing: goal),
              );
            },
          ),
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.savings_outlined),
          label: Text(l10n.addSavingsGoal),
        ),
      ],
    );
  }
}
