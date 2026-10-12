part of '../event_list_item.dart';

List<Widget> _buildEventSubtitleLines(
  BuildContext context, {
  required AppLocalizations l10n,
  required AppEvent event,
  required String? profileLabel,
  required bool showInlineActions,
  required bool isScheduleEvent,
  bool omitEventTime = false,
  int? notesMaxLines,
  bool omitChecklistProgress = false,
}) {
  final omitTimeForIndicators =
      !omitEventTime &&
      !showInlineActions &&
      _EventFeatureIndicators.hasAny(
        event: event,
        isScheduleEvent: isScheduleEvent,
      );

  final info = EventDisplayInfo.from(
    event,
    l10n,
    profileLabel: profileLabel,
    omitEventTime: omitEventTime || omitTimeForIndicators,
    omitChecklistProgress: omitChecklistProgress,
  );

  final mutedStyle = Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted);

  final widgets = <Widget>[];

  if (info.profileLabel != null) {
    widgets.add(
      Text(
        info.profileLabel!,
        style: mutedStyle?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  for (final line in info.detailLines) {
    if (widgets.isNotEmpty) {
      widgets.add(const SizedBox(height: 2));
    }
    widgets.add(
      Text(
        line,
        style: mutedStyle,
        maxLines: notesMaxLines,
        overflow: notesMaxLines == null ? null : TextOverflow.ellipsis,
      ),
    );
  }

  return widgets;
}

IconData _entryKindIcon(CalendarEntryKind kind) {
  switch (kind) {
    case CalendarEntryKind.event:
      return Icons.event_outlined;
    case CalendarEntryKind.note:
      return Icons.sticky_note_2_outlined;
    case CalendarEntryKind.checklist:
      return Icons.checklist_rtl_outlined;
    case CalendarEntryKind.savingsGoal:
      return Icons.savings_outlined;
  }
}

class _EventFeatureIndicators extends StatelessWidget {
  const _EventFeatureIndicators({
    required this.event,
    required this.isScheduleEvent,
    required this.compact,
    this.timeRange,
  });

  final AppEvent event;
  final bool isScheduleEvent;
  final bool compact;
  final String? timeRange;

  static bool hasAny({required AppEvent event, required bool isScheduleEvent}) {
    if (event.hasFinanceMarker) return true;
    if (event.hasAttachments) return true;
    if (event.kind == CalendarEntryKind.note) {
      return event.hasFinanceMarker || event.hasAttachments;
    }
    if (event.kind == CalendarEntryKind.checklist) {
      return event.hasRecurrence || event.reminderMinutesBefore != null;
    }
    return event.hasRecurrence || event.reminderMinutesBefore != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final display = EventDisplayInfo.from(
      event,
      l10n,
      compactMetaLabels: compact,
    );
    return Wrap(
      spacing: AlmanacSpacing.xxs,
      runSpacing: AlmanacSpacing.xxs,
      children: [
        for (final chip in display.metaChips)
          _EventFeatureChip(
            icon: chip.icon,
            label: chip.label,
            tooltip: chip.tooltip,
            color: _chipColor(context, chip.icon, scheme),
            compact: compact,
          ),
        if (compact && timeRange != null && display.metaChips.isEmpty)
          _EventFeatureChip(
            icon: Icons.schedule_rounded,
            label: timeRange,
            tooltip: timeRange!,
            color: scheme.onSurfaceVariant,
            compact: compact,
          ),
      ],
    );
  }

  Color _chipColor(BuildContext context, IconData icon, ColorScheme scheme) {
    if (icon == Icons.repeat_rounded) {
      return context.profileHighlight.warmAccent;
    }
    if (icon == Icons.payments_outlined) {
      return context.almanacColors.success;
    }
    if (icon == Icons.attach_file_outlined) {
      return scheme.secondary;
    }
    return scheme.primary;
  }
}

class _EventFeatureChip extends StatelessWidget {
  const _EventFeatureChip({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.compact,
    this.label,
  });

  final IconData icon;
  final String? label;
  final String tooltip;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
      fontSize: compact ? 10 : 11,
    );
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AlmanacSpacing.xxs + 2 : AlmanacSpacing.xs,
          vertical: compact ? 2 : AlmanacSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AlmanacRadius.control,
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 13 : 14, color: color),
            if (label != null) ...[
              const SizedBox(width: AlmanacSpacing.xxs),
              Text(label!, style: textStyle),
            ],
          ],
        ),
      ),
    );
  }
}
