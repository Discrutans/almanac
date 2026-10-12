import 'package:flutter/material.dart';
import '../../../data/events/event_overlap.dart';
import '../../../data/events/recurrence_exdate.dart';
import '../../../data/events/recurrence_engine.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_buttons.dart';
import '../../../core/ui/almanac_form_panel.dart';
import '../../../core/ui/almanac_time_field.dart';
import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../../note_attachment.dart';
import '../../event_time_utils.dart';
import 'event_entry_form_body.dart';
import 'event_color_swatches.dart';
import 'event_form_parsing.dart';
import 'checklist_editor.dart';
import '../../../data/attachments/attachment_storage.dart';

part 'edit_event_dialog_actions.dart';

typedef EditEventSaveCallback =
    Future<void> Function(
      AppEvent event, {
      RecurrenceEditScope recurrenceScope,
    });

/// Диалог редактирования записи календаря.
class EditEventDialog extends StatefulWidget {
  const EditEventDialog({
    super.key,
    required this.event,
    required this.existingEvents,
    required this.onSave,
    this.onDelete,
    this.onRevertOverride,
    this.allowDelete = true,
    this.allowRevertOverride = false,
    this.onCancel,
  });

  final AppEvent event;
  final List<AppEvent> existingEvents;
  final EditEventSaveCallback onSave;
  final Future<void> Function(AppEvent event)? onDelete;
  final Future<void> Function(AppEvent event)? onRevertOverride;
  final bool allowDelete;
  final bool allowRevertOverride;

  /// Если задано, «Отмена» возвращает к просмотру вместо закрытия панели.
  final VoidCallback? onCancel;

  static Future<void> show({
    required BuildContext context,
    required AppEvent event,
    required List<AppEvent> existingEvents,
    required EditEventSaveCallback onSave,
    Future<void> Function(AppEvent event)? onDelete,
    Future<void> Function(AppEvent event)? onRevertOverride,
    bool allowDelete = true,
    bool allowRevertOverride = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.editEntryTitleForKind(event.kind),
      child: EditEventDialog(
        event: event,
        existingEvents: existingEvents,
        onSave: onSave,
        onDelete: onDelete,
        onRevertOverride: onRevertOverride,
        allowDelete: allowDelete,
        allowRevertOverride: allowRevertOverride,
      ),
    );
  }

  @override
  State<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<EditEventDialog>
    with _EditEventDialogActions {
  static bool _isPresetColor(Color color) {
    final value = color.toARGB32();
    return EventColorPresets.swatches.any(
      (swatch) => swatch.toARGB32() == value,
    );
  }

  static bool _hasAdvancedFields(AppEvent event) {
    if (event.kind == CalendarEntryKind.note) {
      return event.hasFinanceMarker ||
          event.hasAttachments ||
          (event.notes != null && event.notes!.isNotEmpty) ||
          !_isPresetColor(event.color);
    }
    if (event.kind == CalendarEntryKind.checklist) {
      return event.hasPomodoro || !_isPresetColor(event.color);
    }
    return event.kind == CalendarEntryKind.event &&
        (event.reminderMinutesBefore != null ||
            event.overtimeMinutes != null ||
            event.shiftSkipped ||
            event.unpaidMinutes != null ||
            event.hasFinanceMarker ||
            event.hasPomodoro ||
            (event.notes != null && event.notes!.isNotEmpty) ||
            RecurrencePresetX.fromRrule(event.rrule) != RecurrencePreset.none ||
            event.recurrenceUntil != null ||
            event.isGift ||
            !_isPresetColor(event.color));
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text:
          widget.event.kind == CalendarEntryKind.note &&
              widget.event.isAutoDerivedNoteTitle
          ? ''
          : widget.event.title,
    );
    _startController = TextEditingController(text: widget.event.startTime);
    _endController = TextEditingController(text: widget.event.endTime);
    _notesController = TextEditingController(text: widget.event.notes ?? '');
    _incomeController = TextEditingController(
      text: widget.event.incomeAmount == null
          ? ''
          : widget.event.incomeAmount!.toString(),
    );
    _pomodoroWorkController = TextEditingController(
      text: widget.event.pomodoroWorkMinutes.toString(),
    );
    _pomodoroBreakController = TextEditingController(
      text: widget.event.pomodoroBreakMinutes.toString(),
    );
    _overtimeController = TextEditingController(
      text: widget.event.overtimeMinutes?.toString() ?? '',
    );
    _unpaidMinutesController = TextEditingController(
      text: widget.event.unpaidMinutes?.toString() ?? '',
    );
    _shiftSkipped = widget.event.shiftSkipped;
    _selectedColor = widget.event.color;
    _checklist = widget.event.checklist;
    _attachments = List<NoteAttachment>.from(widget.event.attachments);
    _recurrence = RecurrencePresetX.fromRrule(widget.event.rrule);
    _recurrenceUntil = widget.event.recurrenceUntil;
    _reminderMinutesBefore = widget.event.reminderMinutesBefore;
    _pomodoroEnabled = widget.event.pomodoroEnabled;
    _kind = widget.event.kind;
    _isGift = widget.event.isGift;
    _showMoreOptions = _hasAdvancedFields(widget.event);
    _recurrenceEditScope = RecurrenceEditScope.wholeSeries;
    _startController.addListener(_onTimeFieldsChanged);
    _endController.addListener(_onTimeFieldsChanged);
  }

  void _onTimeFieldsChanged() {
    if (mounted) setState(() {});
  }

  /// Non-blocking hint when the timed range overlaps another personal event.
  String? _timedOverlapWarning(AppLocalizations l10n) {
    if (_kind != CalendarEntryKind.event) return null;

    final eventDate = calendarDayKey(widget.event.start);

    if (_isScheduleEvent) {
      final start = parseAlmanacTime(_startController.text);
      final end = parseAlmanacTime(_endController.text);
      if (start == null || end == null) return null;

      final startDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        start.hour,
        start.minute,
      );
      var endDateTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        end.hour,
        end.minute,
      );
      if (!end.isAfter(start)) {
        endDateTime = endDateTime.add(const Duration(days: 1));
      }

      final conflicts = findScheduleEditConflicts(
        candidateStart: startDateTime,
        candidateEnd: endDateTime,
        existingEvents: widget.existingEvents,
        editingEvent: widget.event,
      );
      return conflicts.isEmpty ? null : l10n.eventOverlapWarning;
    }

    final parsed = parsePersonalEventTimes(
      startRaw: _startController.text,
      endRaw: _endController.text,
    );
    if (parsed == null) return null;

    final range = buildPersonalEventDateTimeRange(
      day: eventDate,
      start: parsed.start,
      end: parsed.end,
    );
    final excludeId = widget.event.isRecurrenceOccurrence
        ? null
        : widget.event.id;
    final excludeSeriesId = widget.event.isRecurrenceOccurrence
        ? null
        : (widget.event.seriesId ?? widget.event.id);

    if (!hasEventConflict(
      candidateStart: range.start,
      candidateEnd: range.end,
      existingEvents: widget.existingEvents,
      excludeEventId: excludeId,
      excludeSeriesId: excludeSeriesId,
    )) {
      return null;
    }
    return l10n.eventOverlapWarning;
  }

  @override
  void dispose() {
    _startController.removeListener(_onTimeFieldsChanged);
    _endController.removeListener(_onTimeFieldsChanged);
    _titleController.dispose();
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    _incomeController.dispose();
    _pomodoroWorkController.dispose();
    _pomodoroBreakController.dispose();
    _overtimeController.dispose();
    _unpaidMinutesController.dispose();
    super.dispose();
  }

  void _onKindChanged(CalendarEntryKind kind) {
    setState(() {
      _kind = kind;
      if (kind != CalendarEntryKind.event) {
        _recurrence = RecurrencePreset.none;
        _recurrenceUntil = null;
        _reminderMinutesBefore = null;
        _isGift = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final overlapWarning = _timedOverlapWarning(l10n);

    return AlmanacFormPanel(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.event.isRecurrenceOccurrence && !_isScheduleEvent) ...[
            Text(
              l10n.editRecurrenceScopeLabel,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            SegmentedButton<RecurrenceEditScope>(
              segments: [
                ButtonSegment(
                  value: RecurrenceEditScope.thisOccurrenceOnly,
                  label: Text(l10n.editThisOccurrence),
                ),
                ButtonSegment(
                  value: RecurrenceEditScope.wholeSeries,
                  label: Text(l10n.editWholeSeries),
                ),
              ],
              selected: {_recurrenceEditScope},
              onSelectionChanged: (selection) {
                setState(() => _recurrenceEditScope = selection.first);
              },
            ),
            const SizedBox(height: AlmanacSpacing.sm),
          ],
          if (widget.event.isRecurrenceOccurrence &&
              !_isScheduleEvent &&
              _recurrenceEditScope == RecurrenceEditScope.wholeSeries) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AlmanacSpacing.sm,
                vertical: AlmanacSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: AlmanacRadius.control,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: AlmanacSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.editRecurrenceSeriesBanner,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
          ],
          if (_isScheduleEvent)
            Padding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
              child: Text(
                l10n.scheduleEventHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          EventEntryFormBody(
            kind: _kind,
            titleController: _titleController,
            startController: _startController,
            endController: _endController,
            notesController: _notesController,
            incomeController: _incomeController,
            pomodoroWorkController: _pomodoroWorkController,
            pomodoroBreakController: _pomodoroBreakController,
            overtimeController: _overtimeController,
            unpaidMinutesController: _unpaidMinutesController,
            selectedColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
            checklist: _checklist,
            onChecklistChanged: (items) => setState(() => _checklist = items),
            checklistEditorKey: _checklistEditorKey,
            attachments: _attachments,
            onAttachmentsChanged: (attachments) =>
                setState(() => _attachments = attachments),
            attachmentsEventId: widget.event.id,
            onAttachmentsError: (message) => setState(() => _error = message),
            pomodoroEnabled: _pomodoroEnabled,
            onPomodoroEnabledChanged: (value) =>
                setState(() => _pomodoroEnabled = value),
            recurrence: _recurrence,
            onRecurrenceChanged: (value) => setState(() {
              _recurrence = value;
              if (value == RecurrencePreset.none) {
                _recurrenceUntil = null;
              }
            }),
            recurrenceUntil: _recurrenceUntil,
            onRecurrenceUntilChanged: (value) =>
                setState(() => _recurrenceUntil = value),
            recurrenceFirstDate: calendarDayKey(widget.event.start),
            customRrule: _recurrence == RecurrencePreset.custom
                ? RecurrenceExdateCodec.baseRrule(widget.event.rrule)
                : null,
            isGift: _isGift,
            onGiftChanged: (value) => setState(() => _isGift = value),
            reminderMinutesBefore: _reminderMinutesBefore,
            onReminderChanged: (value) =>
                setState(() => _reminderMinutesBefore = value),
            showMoreOptions: _showMoreOptions,
            onToggleMoreOptions: () =>
                setState(() => _showMoreOptions = !_showMoreOptions),
            showKindSelector: !_isScheduleEvent,
            onKindChanged: _isScheduleEvent ? null : _onKindChanged,
            isScheduleEvent: _isScheduleEvent,
            shiftSkipped: _shiftSkipped,
            onShiftSkippedChanged: _isScheduleEvent
                ? (value) {
                    setState(() {
                      _shiftSkipped = value;
                      if (value) {
                        _overtimeController.clear();
                        _unpaidMinutesController.clear();
                      }
                    });
                  }
                : null,
            endTimeOptional: !_isScheduleEvent,
            showNotesInMoreOptions: !_isScheduleEvent,
            showRecurrence:
                !_isScheduleEvent &&
                _recurrenceEditScope == RecurrenceEditScope.wholeSeries,
          ),
          if (overlapWarning != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              overlapWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
        ],
      ),
      actions: AlmanacDialogActions(
        children: [
          if (widget.allowRevertOverride && widget.onRevertOverride != null)
            TextButton(
              onPressed: (_isSaving || _isDeleting) ? null : _confirmRevert,
              child: _isDeleting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Text(l10n.revertScheduleOverride),
            ),
          if (widget.allowDelete &&
              !_isScheduleEvent &&
              widget.onDelete != null)
            TextButton(
              onPressed: (_isSaving || _isDeleting) ? null : _confirmDelete,
              style: TextButton.styleFrom(
                foregroundColor: context.almanacColors.danger,
              ),
              child: _isDeleting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.almanacColors.danger,
                      ),
                    )
                  : Text(l10n.deleteEvent),
            ),
          TextButton(
            onPressed: (_isSaving || _isDeleting)
                ? null
                : () {
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
            child: Text(l10n.cancel),
          ),
          AlmanacAsyncFilledButton(
            label: l10n.save,
            isLoading: _isSaving,
            onPressed: (_isSaving || _isDeleting) ? null : _save,
          ),
        ],
      ),
    );
  }
}
