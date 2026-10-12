import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_form_panel.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../../pomodoro/pomodoro_live_indicator.dart';
import '../../../pomodoro/pomodoro_timer_sheet.dart';
import '../../calendar_entry_capabilities.dart';
import '../../calendar_types.dart';
import '../../event_display_info.dart';
import '../../event_profile_visual.dart';
import '../forms/checklist_tree.dart';
import '../forms/edit_event_dialog.dart';
import '../forms/note_attachments_section.dart';

/// Просмотр записи: «Изменить» открывает форму в этой же панели.
class EventPreviewSheet extends StatefulWidget {
  const EventPreviewSheet({
    super.key,
    required this.event,
    required this.activeProfileId,
    this.onSave,
    this.onDelete,
    this.onRevertOverride,
    this.onEditSavings,
    this.onEventUpdated,
    this.onDuplicate,
    this.existingEvents = const [],
    this.allowDelete = true,
    this.allowRevertOverride = false,
    this.profileLabel,
    this.profileSeedColor,
    this.startInEdit = false,
    this.allowEdit = true,
    this.acquireEditLock,
    this.releaseEditLock,
    this.actionLabel,
    this.onAction,
  });

  final AppEvent event;
  final String activeProfileId;
  final EditEventSaveCallback? onSave;
  final Future<void> Function(AppEvent event)? onDelete;
  final Future<void> Function(AppEvent event)? onRevertOverride;
  final VoidCallback? onEditSavings;
  final ValueChanged<AppEvent>? onEventUpdated;
  final Future<void> Function(AppEvent event)? onDuplicate;
  final List<AppEvent> existingEvents;
  final bool allowDelete;
  final bool allowRevertOverride;
  final String? profileLabel;
  final Color? profileSeedColor;
  final bool startInEdit;
  final bool allowEdit;
  final Future<bool> Function()? acquireEditLock;
  final Future<void> Function()? releaseEditLock;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  static Future<void> show({
    required BuildContext context,
    required AppEvent event,
    required String activeProfileId,
    EditEventSaveCallback? onSave,
    Future<void> Function(AppEvent event)? onDelete,
    Future<void> Function(AppEvent event)? onRevertOverride,
    VoidCallback? onEditSavings,
    ValueChanged<AppEvent>? onEventUpdated,
    Future<void> Function(AppEvent event)? onDuplicate,
    List<AppEvent> existingEvents = const [],
    bool allowDelete = true,
    bool allowRevertOverride = false,
    String? profileLabel,
    Color? profileSeedColor,
    bool startInEdit = false,
    bool allowEdit = true,
    Future<bool> Function()? acquireEditLock,
    Future<void> Function()? releaseEditLock,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.viewEntryTitleForKind(event.kind),
      size: AlmanacPanelSize.cover,
      useSafeArea: false,
      child: EventPreviewSheet(
        event: event,
        activeProfileId: activeProfileId,
        onSave: onSave,
        onDelete: onDelete,
        onRevertOverride: onRevertOverride,
        onEditSavings: onEditSavings,
        onEventUpdated: onEventUpdated,
        onDuplicate: onDuplicate,
        existingEvents: existingEvents,
        allowDelete: allowDelete,
        allowRevertOverride: allowRevertOverride,
        profileLabel: profileLabel,
        profileSeedColor: profileSeedColor,
        startInEdit: startInEdit && allowEdit,
        allowEdit: allowEdit,
        acquireEditLock: acquireEditLock,
        releaseEditLock: releaseEditLock,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }

  @override
  State<EventPreviewSheet> createState() => _EventPreviewSheetState();
}

class _EventPreviewSheetState extends State<EventPreviewSheet> {
  late var _editing =
      widget.startInEdit &&
      widget.acquireEditLock == null &&
      !widget.event.isSavingsGoal;
  var _openingEditor = false;
  String? _lockMessage;

  @override
  void initState() {
    super.initState();
    if (widget.startInEdit && widget.event.isSavingsGoal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_beginEdit());
      });
      return;
    }
    if (widget.startInEdit &&
        widget.acquireEditLock != null &&
        !widget.event.isSavingsGoal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_beginEdit());
      });
    }
  }

  @override
  void dispose() {
    final release = widget.releaseEditLock;
    if (release != null) {
      unawaited(release());
    }
    super.dispose();
  }

  void _openEditor() {
    unawaited(_beginEdit());
  }

  Future<void> _beginEdit() async {
    if (_openingEditor || _editing) return;
    if (widget.event.isSavingsGoal) {
      final openSavings = widget.onEditSavings;
      if (openSavings == null) return;
      Navigator.of(context).pop();
      openSavings();
      return;
    }
    if (widget.onSave == null) return;
    final acquire = widget.acquireEditLock;
    if (acquire != null) {
      setState(() => _openingEditor = true);
      final ok = await acquire();
      if (!mounted) return;
      setState(() => _openingEditor = false);
      if (!ok) {
        setState(
          () => _lockMessage = AppLocalizations.of(context).eventLockedByOther,
        );
        return;
      }
    }
    setState(() {
      _lockMessage = null;
      _editing = true;
    });
  }

  Future<void> _leaveEditor() async {
    await widget.releaseEditLock?.call();
    if (!mounted) return;
    setState(() => _editing = false);
  }

  Future<void> _duplicate() async {
    final duplicate = widget.onDuplicate;
    if (duplicate == null) return;
    final event = widget.event;
    Navigator.of(context).pop();
    await duplicate(event);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing && widget.onSave != null) {
      return EditEventDialog(
        event: widget.event,
        existingEvents: widget.existingEvents,
        onSave: widget.onSave!,
        onDelete: widget.onDelete,
        onRevertOverride: widget.onRevertOverride,
        allowDelete: widget.allowDelete,
        allowRevertOverride: widget.allowRevertOverride,
        onCancel: () => unawaited(_leaveEditor()),
      );
    }
    return _buildPreview(context);
  }

  Widget _buildPreview(BuildContext context) {
    final event = widget.event;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final marker = eventMarkerColor(event, widget.activeProfileId);
    final display = EventDisplayInfo.from(
      event,
      l10n,
      profileLabel: widget.profileLabel,
      omitEventTime: true,
      omitChecklistProgress: event.kind == CalendarEntryKind.checklist,
    );
    final showHeading =
        !(event.kind == CalendarEntryKind.note && event.isAutoDerivedNoteTitle);
    final notesBody = event.kind == CalendarEntryKind.note
        ? (event.isAutoDerivedNoteTitle
              ? event.notes?.trim()
              : event.noteDisplaySecondary)
        : null;
    final detailLines = [
      for (final line in display.detailLines)
        if (notesBody == null || line != notesBody) line,
    ];
    final metaChips = [
      for (final chip in display.metaChips)
        if (chip.icon != Icons.attach_file_outlined) chip,
    ];
    final day = event.start.toLocal();
    final checklistEntries = event.kind == CalendarEntryKind.checklist
        ? flattenChecklistTree(event.checklist)
        : const <ChecklistTreeEntry>[];

    return AlmanacFormPanel(
      actions: widget.onAction == null || widget.actionLabel == null
          ? const SizedBox.shrink()
          : SizedBox(
              width: double.infinity,
              height: AlmanacSizes.buttonHeight,
              child: FilledButton(
                onPressed: () => unawaited(widget.onAction!()),
                child: Text(widget.actionLabel!),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: marker,
                  borderRadius: AlmanacRadius.control,
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    display.listIcon,
                    color: AlmanacBrand.onFill(marker),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: AlmanacSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: AlmanacSizes.buttonHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: showHeading
                        ? SelectableText(
                            display.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(width: AlmanacSpacing.xxs),
              if (widget.onDuplicate != null)
                _PreviewDuplicateButton(
                  onDuplicate: () => unawaited(_duplicate()),
                ),
              if (widget.allowEdit) ...[
                if (widget.onDuplicate != null)
                  const SizedBox(width: AlmanacSpacing.xxs),
                _PreviewEditButton(onEdit: _openEditor, busy: _openingEditor),
              ],
            ],
          ),
          if (_lockMessage != null ||
              (!widget.allowEdit && widget.acquireEditLock != null)) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              _lockMessage ?? AppLocalizations.of(context).eventLockedByOther,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 40 + AlmanacSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.isUndated
                      ? l10n.undatedEntryLabel
                      : l10n.fullDate(day),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (display.timeRange != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    display.timeRange!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (display.isScheduleEvent) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              l10n.fromWorkSchedule,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (widget.profileLabel != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (widget.profileSeedColor ?? scheme.primary).withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: AlmanacRadius.chip,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AlmanacSpacing.xs,
                    vertical: 4,
                  ),
                  child: Text(
                    widget.profileLabel!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.profileSeedColor ?? scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (metaChips.isNotEmpty) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Wrap(
              spacing: AlmanacSpacing.xs,
              runSpacing: AlmanacSpacing.xs,
              children: [
                for (final chip in metaChips)
                  _PreviewChip(
                    icon: chip.icon,
                    label: chip.label ?? chip.tooltip,
                  ),
              ],
            ),
          ],
          if (notesBody != null && notesBody.isNotEmpty) ...[
            const SizedBox(height: AlmanacSpacing.md),
            SelectableText(
              notesBody,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.35),
            ),
          ],
          if (event.kind != CalendarEntryKind.note)
            for (final line in detailLines) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              SelectableText(
                line,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  height: 1.35,
                ),
              ),
            ],
          if (event.kind == CalendarEntryKind.note)
            for (final line in detailLines)
              if (line != l10n.notes) ...[
                const SizedBox(height: AlmanacSpacing.sm),
                SelectableText(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
          if (checklistEntries.isNotEmpty) ...[
            const SizedBox(height: AlmanacSpacing.md),
            for (final entry in checklistEntries)
              Padding(
                padding: EdgeInsets.only(
                  left: entry.depth * AlmanacSpacing.md,
                  bottom: AlmanacSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.item.completed
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: entry.item.completed
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AlmanacSpacing.xs),
                    Expanded(
                      child: Text(
                        entry.item.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: entry.item.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: entry.item.completed
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (event.hasAttachments) ...[
            const SizedBox(height: AlmanacSpacing.md),
            NoteAttachmentsSection(
              eventId: event.id,
              attachments: event.attachments,
              onChanged: (_) {},
              readOnly: true,
            ),
          ],
          if (event.hasPomodoro) ...[
            const SizedBox(height: AlmanacSpacing.md),
            PomodoroLiveIndicator(
              event: event,
              onEventUpdated: widget.onEventUpdated,
              expandToWidth: true,
            ),
          ] else if (event.capabilities.canSetPomodoro &&
              widget.onEventUpdated != null) ...[
            const SizedBox(height: AlmanacSpacing.md),
            OutlinedButton.icon(
              onPressed: () {
                PomodoroTimerSheet.show(
                  context,
                  event: event,
                  onEventUpdated: widget.onEventUpdated!,
                );
              },
              icon: const Icon(Icons.timer_outlined),
              label: Text(l10n.pomodoroOpenTimer),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewDuplicateButton extends StatelessWidget {
  const _PreviewDuplicateButton({required this.onDuplicate});

  final VoidCallback onDuplicate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.duplicateEntry,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: AlmanacRadius.chip,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDuplicate,
          child: SizedBox(
            width: AlmanacSizes.buttonHeight,
            height: AlmanacSizes.buttonHeight,
            child: Icon(Icons.copy_outlined, size: 18, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}

class _PreviewEditButton extends StatelessWidget {
  const _PreviewEditButton({required this.onEdit, this.busy = false});

  final VoidCallback onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerUp: busy ? null : (_) => onEdit(),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: AlmanacRadius.chip,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onEdit,
          child: SizedBox(
            height: AlmanacSizes.buttonHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AlmanacSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  else
                    Icon(Icons.edit_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.edit,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: AlmanacRadius.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
