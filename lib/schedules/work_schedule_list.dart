part of 'work_schedule_sheet.dart';

class _WorkScheduleSheetState extends ConsumerState<WorkScheduleSheet>
    with _WorkScheduleActions {
  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeProfileNotifierProvider);
    final scheduleRepo = ref.read(cyclicWorkScheduleRepositoryProvider);
    final schedules = scheduleRepo.getForProfile(active.id);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.scheduleProfileHint(active.name),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        if (schedules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AlmanacSpacing.lg),
            child: Text(
              l10n.noSchedulesHint,
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
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              final kindLabel = schedule.isShiftCycle
                  ? l10n.shiftKindLabel(schedule.workDays, schedule.restDays)
                  : l10n.weekdayKindLabel;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AlmanacColorBadge(color: Color(schedule.colorValue)),
                title: Text(schedule.title),
                subtitle: Text(
                  '$kindLabel · ${schedule.startTime}–${schedule.endTime}\n'
                  '${l10n.schedulePatternLabel(isShiftCycle: schedule.isShiftCycle, workDays: schedule.workDays, restDays: schedule.restDays, cycleStartDate: schedule.cycleStartDate, rrule: schedule.rrule)}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.editSchedule,
                      onPressed: () => _editSchedule(context, active, schedule),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: context.almanacColors.danger,
                      ),
                      onPressed: () =>
                          _deleteSchedule(context, active, schedule),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: AlmanacSpacing.sm),
        FilledButton.icon(
          onPressed: () => _openScheduleForm(context, active),
          icon: const Icon(Icons.add),
          label: Text(l10n.addSchedule),
        ),
      ],
    );
  }
}
