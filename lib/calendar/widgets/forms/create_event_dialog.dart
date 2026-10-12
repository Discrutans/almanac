import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';
import '../../../data/events/event_overlap.dart';
import '../../../data/events/recurrence_engine.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_buttons.dart';
import '../../../core/ui/almanac_form_panel.dart';
import '../../calendar_types.dart';
import '../../note_attachment.dart';
import '../../event_time_utils.dart';
import '../../../core/ui/almanac_time_field.dart';
import '../../../core/localization/app_localizations.dart';
import 'checklist_editor.dart';
import 'event_create_form_layout.dart';
import 'event_form_parsing.dart';
import '../../../state/app_providers.dart';

part 'create_event_dialog_actions.dart';

/// Диалог создания записи календаря (событие / заметка / чек-лист).
class CreateEventDialog extends ConsumerStatefulWidget {
  const CreateEventDialog({
    super.key,
    required this.date,
    required this.existingEvents,
    required this.onPersist,
    this.initialKind = CalendarEntryKind.event,
    this.initialStartTime,
    this.initialEndTime,
    this.initialUndated = false,
    this.duplicateFrom,
  });

  final DateTime date;
  final List<AppEvent> existingEvents;
  final Future<void> Function(AppEvent event) onPersist;
  final CalendarEntryKind initialKind;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final bool initialUndated;
  final AppEvent? duplicateFrom;

  static Future<void> show({
    required BuildContext context,
    required DateTime date,
    required List<AppEvent> existingEvents,
    required Future<void> Function(AppEvent event) onPersist,
    CalendarEntryKind initialKind = CalendarEntryKind.event,
    TimeOfDay? initialStartTime,
    TimeOfDay? initialEndTime,
    bool initialUndated = false,
    AppEvent? duplicateFrom,
  }) {
    final l10n = AppLocalizations.of(context);
    final kind = duplicateFrom?.kind ?? initialKind;
    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.createEntryTitleForKind(kind),
      hideTitle: true,
      child: CreateEventDialog(
        date: date,
        existingEvents: existingEvents,
        onPersist: onPersist,
        initialKind: kind,
        initialStartTime: initialStartTime,
        initialEndTime: initialEndTime,
        initialUndated: initialUndated,
        duplicateFrom: duplicateFrom,
      ),
    );
  }

  @override
  ConsumerState<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends ConsumerState<CreateEventDialog>
    with _CreateEventDialogActions {
  @override
  void initState() {
    super.initState();
    final source = widget.duplicateFrom;
    _kind = source?.kind ?? widget.initialKind;
    _draftEventId = 'event-${DateTime.now().millisecondsSinceEpoch}';
    _isUndated =
        source?.isUndated ??
        (widget.initialUndated && _kind != CalendarEntryKind.event);
    _startDate = DateTime(widget.date.year, widget.date.month, widget.date.day);
    _endDate = _startDate;
    if (source != null) {
      _prefillFrom(source);
    } else {
      final start = widget.initialStartTime;
      if (start == null) {
        _startController.text = '08:00';
        _endController.text = '10:30';
      } else {
        _startController.text = formatAlmanacTime(start);
        final end = widget.initialEndTime;
        if (end == null) {
          var endMinutes =
              start.hour * 60 + start.minute + kWeekDefaultTimedDurationMinutes;
          if (endMinutes >= 24 * 60) {
            _endDate = _startDate.add(const Duration(days: 1));
            endMinutes -= 24 * 60;
          }
          _endController.text = formatAlmanacTime(
            timeOfDayFromMinutes(endMinutes),
          );
        } else {
          final startMinutes = start.hour * 60 + start.minute;
          if (end.hour == 0 && end.minute == 0 && startMinutes > 0) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
          _endController.text = formatAlmanacTime(end);
        }
      }
    }
    _startController.addListener(_onTimeFieldsChanged);
    _endController.addListener(_onTimeFieldsChanged);
  }

  void _prefillFrom(AppEvent source) {
    _titleController.text = source.title;
    _notesController.text = source.notes ?? '';
    _selectedColor = source.color;
    _selectedProfileId = source.contextProfileId;
    _checklist = [
      for (final item in source.checklist) item.copyWith(),
    ];
    _attachments = List<NoteAttachment>.from(source.attachments);
    _reminderMinutesBefore = source.reminderMinutesBefore;
    _isGift = source.isGift;
    if (source.incomeAmount != null) {
      _incomeController.text = source.incomeAmount!.toString();
    }
    _pomodoroEnabled = source.hasPomodoro;
    if (source.hasPomodoro) {
      _pomodoroWorkController.text = '${source.pomodoroWorkMinutes}';
      _pomodoroBreakController.text = '${source.pomodoroBreakMinutes}';
    }
    _allDay = !source.isTimed || source.startTime.trim().isEmpty;
    final localStart = source.start.toLocal();
    final localEnd = source.end.toLocal();
    _startDate = DateTime(localStart.year, localStart.month, localStart.day);
    _endDate = DateTime(localEnd.year, localEnd.month, localEnd.day);
    if (_allDay) {
      _startController.text = '';
      _endController.text = '';
    } else {
      _startController.text = source.startTime.isNotEmpty
          ? source.startTime
          : formatAlmanacTime(
              TimeOfDay(hour: localStart.hour, minute: localStart.minute),
            );
      _endController.text = source.endTime.isNotEmpty
          ? source.endTime
          : formatAlmanacTime(
              TimeOfDay(hour: localEnd.hour, minute: localEnd.minute),
            );
    }
  }

  void _onTimeFieldsChanged() {
    if (mounted) setState(() {});
  }

  /// Non-blocking hint when the timed range overlaps another personal event.
  String? _timedOverlapWarning(AppLocalizations l10n) {
    if (_kind != CalendarEntryKind.event || _allDay) return null;
    final parsed = parsePersonalEventTimes(
      startRaw: _startController.text,
      endRaw: _endController.text,
    );
    if (parsed == null) return null;

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      parsed.start.hour,
      parsed.start.minute,
    );
    final DateTime endDateTime;
    if (parsed.end == null) {
      endDateTime = startDateTime.add(openEndedEventDuration);
    } else {
      endDateTime = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        parsed.end!.hour,
        parsed.end!.minute,
      );
      if (!endDateTime.isAfter(startDateTime)) return null;
    }

    if (!hasEventConflict(
      candidateStart: startDateTime,
      candidateEnd: endDateTime,
      existingEvents: widget.existingEvents,
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
    super.dispose();
  }

  void _onKindChanged(CalendarEntryKind kind) {
    setState(() {
      _kind = kind;
      if (kind == CalendarEntryKind.event) {
        _isUndated = false;
      }
      if (kind != CalendarEntryKind.event) {
        _recurrence = RecurrencePreset.none;
        _recurrenceUntil = null;
        _reminderMinutesBefore = null;
        _isGift = false;
        _allDay = false;
      }
    });
  }

  void _onAllDayChanged(bool value) {
    setState(() {
      _allDay = value;
      if (value) {
        _reminderMinutesBefore = null;
      }
    });
  }

  Future<void> _pickFormDate({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    onChanged(DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final overlapWarning = _timedOverlapWarning(l10n);
    final selectedColor = _selectedColor ?? colorScheme.primary;
    final profilesState = ref.watch(contextProfilesProvider);
    final selectedProfileId = _selectedProfileId ?? profilesState.active.id;

    return AlmanacFormPanel(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EventCreateFormLayout(
            kind: _kind,
            profiles: profilesState.profiles,
            selectedProfileId: selectedProfileId,
            onProfileChanged: (profileId) =>
                setState(() => _selectedProfileId = profileId),
            titleController: _titleController,
            startController: _startController,
            endController: _endController,
            notesController: _notesController,
            incomeController: _incomeController,
            selectedColor: selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
            checklist: _checklist,
            onChecklistChanged: (items) => setState(() => _checklist = items),
            checklistEditorKey: _checklistEditorKey,
            attachments: _attachments,
            onAttachmentsChanged: (attachments) =>
                setState(() => _attachments = attachments),
            attachmentsEventId: _draftEventId,
            onAttachmentsError: (message) => setState(() => _error = message),
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
            recurrenceFirstDate: _startDate,
            isGift: _isGift,
            onGiftChanged: (value) => setState(() => _isGift = value),
            reminderMinutesBefore: _reminderMinutesBefore,
            onReminderChanged: (value) =>
                setState(() => _reminderMinutesBefore = value),
            onKindChanged: _onKindChanged,
            startDate: _startDate,
            endDate: _endDate,
            onStartDateChanged: (date) => setState(() {
              _startDate = date;
              if (_endDate.isBefore(_startDate)) {
                _endDate = _startDate;
              }
            }),
            onEndDateChanged: (date) => setState(() => _endDate = date),
            allDay: _allDay,
            onAllDayChanged: _onAllDayChanged,
            onPickDate: _pickFormDate,
            autofocusNote: _kind == CalendarEntryKind.note,
            autofocusTitle: _kind != CalendarEntryKind.note,
            isUndated: _isUndated,
            onUndatedChanged: (value) => setState(() => _isUndated = value),
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
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          AlmanacAsyncFilledButton(
            label: l10n.save,
            isLoading: _isSaving,
            onPressed: _create,
          ),
        ],
      ),
    );
  }
}
