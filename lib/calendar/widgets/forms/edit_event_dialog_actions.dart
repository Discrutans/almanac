part of 'edit_event_dialog.dart';

mixin _EditEventDialogActions on State<EditEventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _notesController;
  late final TextEditingController _incomeController;
  late final TextEditingController _pomodoroWorkController;
  late final TextEditingController _pomodoroBreakController;
  late final TextEditingController _overtimeController;
  late final TextEditingController _unpaidMinutesController;
  late Color _selectedColor;
  late List<ChecklistItem> _checklist;
  late List<NoteAttachment> _attachments;
  late RecurrencePreset _recurrence;
  late DateTime? _recurrenceUntil;
  late int? _reminderMinutesBefore;
  late CalendarEntryKind _kind;
  late bool _pomodoroEnabled;
  late bool _shiftSkipped;
  late bool _isGift;
  String? _error;
  bool _isSaving = false;
  bool _isDeleting = false;
  late bool _showMoreOptions;
  late RecurrenceEditScope _recurrenceEditScope;
  final _checklistEditorKey = GlobalKey<ChecklistEditorState>();

  bool get _isScheduleEvent => widget.event.entrySource.isScheduleRelated;

  String _resolveTitle(AppLocalizations l10n) {
    return EventFormParsing.resolveTitle(
      kind: _kind,
      titleRaw: _titleController.text,
      notesRaw: _notesController.text,
      l10n: l10n,
    );
  }

  String? _notesOrNull() => EventFormParsing.notesOrNull(_notesController.text);

  double? _parseIncomeAmount(AppLocalizations l10n) {
    final result = EventFormParsing.parseIncomeAmount(
      raw: _incomeController.text,
      l10n: l10n,
    );
    if (result.error != null) {
      setState(() => _error = result.error);
    }
    return result.amount;
  }

  ({int work, int breakMinutes})? _parsePomodoroMinutes(AppLocalizations l10n) {
    final result = EventFormParsing.parsePomodoroMinutes(
      enabled: _pomodoroEnabled,
      workRaw: _pomodoroWorkController.text,
      breakRaw: _pomodoroBreakController.text,
      l10n: l10n,
      forceDefaults: _isScheduleEvent,
    );
    if (result.error != null) {
      setState(() => _error = result.error);
      return null;
    }
    return (work: result.work, breakMinutes: result.breakMinutes);
  }

  Future<void> _save() async {
    if (_isSaving || _isDeleting) return;

    setState(() => _error = null);

    final l10n = AppLocalizations.of(context);
    final eventDate = calendarDayKey(widget.event.start);

    if (_kind == CalendarEntryKind.note && !_isScheduleEvent) {
      final notes = _notesController.text.trim();
      if (notes.isEmpty) {
        setState(() => _error = l10n.emptyNoteBody);
        return;
      }

      final incomeAmount = _parseIncomeAmount(l10n);
      if (_error != null) return;

      await _persistUpdated(
        widget.event.copyWith(
          kind: CalendarEntryKind.note,
          title: _resolveTitle(l10n),
          dateTimeRange: AppEvent.dateOnlyRange(eventDate),
          startTime: '',
          endTime: '',
          color: _selectedColor,
          checklist: const [],
          rrule: null,
          seriesId: null,
          isRecurrenceOccurrence: false,
          notes: notes,
          incomeAmount: incomeAmount,
          isGift: _isGift,
          clearIncomeAmount: incomeAmount == null,
          attachments: _attachments,
          reminderMinutesBefore: null,
          overtimeMinutes: null,
        ),
      );
      return;
    }

    if (_kind == CalendarEntryKind.checklist && !_isScheduleEvent) {
      _checklistEditorKey.currentState?.commitPendingDraft();

      if (_checklist.isEmpty) {
        setState(() => _error = l10n.emptyChecklistItems);
        return;
      }

      final pomodoro = _parsePomodoroMinutes(l10n);
      if (_error != null || pomodoro == null) return;

      await _persistUpdated(
        widget.event.copyWith(
          kind: CalendarEntryKind.checklist,
          title: _resolveTitle(l10n),
          dateTimeRange: AppEvent.dateOnlyRange(eventDate),
          startTime: '',
          endTime: '',
          color: _selectedColor,
          checklist: _checklist,
          rrule: null,
          seriesId: null,
          isRecurrenceOccurrence: false,
          notes: null,
          reminderMinutesBefore: null,
          overtimeMinutes: null,
          pomodoroEnabled: _pomodoroEnabled,
          pomodoroWorkMinutes: pomodoro.work,
          pomodoroBreakMinutes: pomodoro.breakMinutes,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.emptyTitle);
      return;
    }

    if (_isScheduleEvent) {
      final start = parseAlmanacTime(_startController.text);
      final end = parseAlmanacTime(_endController.text);

      if (start == null || end == null) {
        setState(() => _error = l10n.invalidTime);
        return;
      }

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

      // Overlaps with personal events are allowed; warning is shown in the form UI.

      final overtimeRaw = _overtimeController.text.trim();
      final overtimeMinutes = _shiftSkipped
          ? null
          : (overtimeRaw.isEmpty ? null : int.tryParse(overtimeRaw));
      final unpaidRaw = _unpaidMinutesController.text.trim();
      final unpaidMinutes = _shiftSkipped
          ? null
          : (unpaidRaw.isEmpty ? null : int.tryParse(unpaidRaw));
      final incomeAmount = _parseIncomeAmount(l10n);
      if (_error != null) return;

      await _persistUpdated(
        widget.event.copyWith(
          id: widget.event.id,
          kind: CalendarEntryKind.event,
          title: title,
          startTime: formatAlmanacTime(start),
          endTime: formatAlmanacTime(end),
          dateTimeRange: DateTimeRange(start: startDateTime, end: endDateTime),
          color: _selectedColor,
          notes: _notesOrNull(),
          incomeAmount: incomeAmount,
          clearIncomeAmount: incomeAmount == null,
          reminderMinutesBefore: _reminderMinutesBefore,
          overtimeMinutes: overtimeMinutes,
          shiftSkipped: _shiftSkipped,
          unpaidMinutes: unpaidMinutes,
          clearOvertimeMinutes: _shiftSkipped && overtimeMinutes == null,
          clearUnpaidMinutes: unpaidMinutes == null,
        ),
      );
      return;
    }

    final parsed = parsePersonalEventTimes(
      startRaw: _startController.text,
      endRaw: _endController.text,
    );
    if (parsed == null) {
      setState(() => _error = l10n.invalidTime);
      return;
    }

    final range = buildPersonalEventDateTimeRange(
      day: eventDate,
      start: parsed.start,
      end: parsed.end,
    );

    // Overlaps are allowed; warning is shown in the form UI.

    final rrule = _recurrence == RecurrencePreset.custom
        ? RecurrenceExdateCodec.baseRrule(widget.event.rrule)
        : _recurrence.rruleString;
    final recurrenceUntil = rrule != null && rrule.isNotEmpty
        ? _recurrenceUntil
        : null;
    final masterId = widget.event.isRecurrenceOccurrence
        ? (widget.event.seriesId ?? widget.event.id)
        : widget.event.id;

    final incomeAmount = _parseIncomeAmount(l10n);
    final pomodoro = _parsePomodoroMinutes(l10n);
    if (_error != null || pomodoro == null) return;

    await _persistUpdated(
      widget.event.copyWith(
        id: masterId,
        kind: CalendarEntryKind.event,
        title: title,
        startTime: formatAlmanacTime(parsed.start),
        endTime: parsed.end == null ? '' : formatAlmanacTime(parsed.end!),
        dateTimeRange: range,
        color: _selectedColor,
        checklist: const [],
        rrule: rrule,
        recurrenceUntil: recurrenceUntil,
        clearRecurrenceUntil:
            (rrule == null || rrule.isEmpty) &&
            widget.event.recurrenceUntil != null,
        seriesId: rrule != null && rrule.isNotEmpty ? masterId : null,
        clearSeriesId: rrule == null || rrule.isEmpty,
        isRecurrenceOccurrence: false,
        notes: _notesOrNull(),
        incomeAmount: incomeAmount,
        isGift: _isGift,
        clearIncomeAmount: incomeAmount == null,
        reminderMinutesBefore: _reminderMinutesBefore,
        pomodoroEnabled: _pomodoroEnabled,
        pomodoroWorkMinutes: pomodoro.work,
        pomodoroBreakMinutes: pomodoro.breakMinutes,
      ),
    );
  }

  Future<void> _persistUpdated(AppEvent updated) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await AttachmentStorage.deleteRemovedAttachments(
        previous: widget.event.attachments,
        current: updated.attachments,
      );
      await widget.onSave(updated, recurrenceScope: _recurrenceEditScope);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = AppLocalizations.of(context).saveFailed(error);
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    if (_isSaving || _isDeleting || widget.onDelete == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.deleteEvent,
      message: l10n.deleteEventConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteEvent,
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await widget.onDelete!(widget.event);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = AppLocalizations.of(context).eventDeleteFailed(error);
        });
      }
    }
  }

  Future<void> _confirmRevert() async {
    if (_isSaving || _isDeleting || widget.onRevertOverride == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.revertScheduleOverride,
      message: l10n.revertScheduleOverrideConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.revertScheduleOverride,
      destructive: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await widget.onRevertOverride!(widget.event);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = AppLocalizations.of(context).eventDeleteFailed(error);
        });
      }
    }
  }
}
