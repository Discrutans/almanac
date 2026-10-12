part of 'work_schedule_sheet.dart';

mixin _WorkScheduleActions on ConsumerState<WorkScheduleSheet> {
  void _reload() => setState(() {});

  Future<void> _deleteSchedule(
    BuildContext context,
    ContextProfile profile,
    CyclicWorkSchedule schedule,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.deleteScheduleTitle,
      message: l10n.deleteScheduleMessage(schedule.title, profile.name),
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.delete,
      destructive: true,
    );

    if (confirmed != true || !context.mounted) return;

    try {
      ref
          .read(cyclicWorkScheduleRepositoryProvider)
          .delete(profileId: profile.id, scheduleId: schedule.id);
      ref
          .read(eventRepositoryProvider)
          .deleteScheduleOverrides(
            profileId: profile.id,
            scheduleId: schedule.id,
          );
      ref.read(schedulesVersionProvider.notifier).state++;
      _reload();
      if (context.mounted) {
        AlmanacFeedback.showSuccess(context, l10n.scheduleDeleted);
      }
    } catch (error) {
      if (context.mounted) {
        AlmanacFeedback.showError(context, l10n.scheduleDeleteFailed(error));
      }
    }
  }

  Future<void> _openScheduleForm(
    BuildContext context,
    ContextProfile profile, {
    CyclicWorkSchedule? existing,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheduleRepo = ref.read(cyclicWorkScheduleRepositoryProvider);

    await showAlmanacSheet<void>(
      context: context,
      placement: widget.placement,
      title: existing != null ? l10n.editScheduleTitle : l10n.newScheduleTitle,
      child: _ScheduleFormDialog(
        existing: existing,
        onPersist: (result) async {
          if (result.title.isEmpty) return;

          final schedule = CyclicWorkSchedule(
            id:
                existing?.id ??
                'sched-${DateTime.now().microsecondsSinceEpoch}',
            profileId: profile.id,
            title: result.title,
            kind: result.kind,
            rrule: result.rrule,
            cycleStartDate: result.cycleStartDate,
            workDays: result.workDays,
            restDays: result.restDays,
            startTime: result.startTime,
            endTime: result.endTime,
            colorValue: result.color.toARGB32(),
            payMode: result.payMode,
            hourlyRate: result.hourlyRate,
            dailyRate: result.dailyRate,
            monthlyRate: result.monthlyRate,
            standardHoursPerShift: result.standardHoursPerShift,
            overtimeMultiplier: result.overtimeMultiplier,
            breakMinutes: result.breakMinutes,
            bonusPercent: result.bonusPercent,
            bonusAmount: result.bonusAmount,
            vatPercent: result.vatPercent,
          );

          if (existing == null) {
            scheduleRepo.add(schedule);
          } else {
            scheduleRepo.update(profileId: profile.id, schedule: schedule);
          }

          ref.read(schedulesVersionProvider.notifier).state++;
        },
      ),
    );

    _reload();
  }

  Future<void> _editSchedule(
    BuildContext context,
    ContextProfile profile,
    CyclicWorkSchedule schedule,
  ) {
    return _openScheduleForm(context, profile, existing: schedule);
  }
}
