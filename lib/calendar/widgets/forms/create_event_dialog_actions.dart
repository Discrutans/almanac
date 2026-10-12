part of 'create_event_dialog.dart';

mixin _CreateEventDialogActions on ConsumerState<CreateEventDialog> {
  final _titleController = TextEditingController();

  final _startController = TextEditingController();

  final _endController = TextEditingController();

  final _notesController = TextEditingController();

  final _incomeController = TextEditingController();

  final _pomodoroWorkController = TextEditingController(text: '25');

  final _pomodoroBreakController = TextEditingController(text: '5');
  Color? _selectedColor;
  List<ChecklistItem> _checklist = const [];
  List<NoteAttachment> _attachments = const [];
  RecurrencePreset _recurrence = RecurrencePreset.none;
  DateTime? _recurrenceUntil;
  int? _reminderMinutesBefore;
  late CalendarEntryKind _kind;
  var _isGift = false;
  late final String _draftEventId;
  final _checklistEditorKey = GlobalKey<ChecklistEditorState>();
  var _pomodoroEnabled = false;
  String? _error;
  bool _isSaving = false;
  var _allDay = false;
  var _isUndated = false;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedProfileId;

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
    );
    if (result.error != null) {
      setState(() => _error = result.error);
      return null;
    }
    return (work: result.work, breakMinutes: result.breakMinutes);
  }

  String _targetProfileId() =>
      _selectedProfileId ?? ref.read(activeProfileIdProvider);

  Future<void> _create() async {
    if (_isSaving) return;

    setState(() => _error = null);

    final l10n = AppLocalizations.of(context);
    final color = _selectedColor ?? Theme.of(context).colorScheme.primary;
    final id = _draftEventId;
    final profileId = _targetProfileId();

    if (_kind == CalendarEntryKind.event) {
      final title = _titleController.text.trim();
      if (title.isEmpty) {
        setState(() => _error = l10n.emptyTitle);
        return;
      }

      final DateTimeRange range;
      String startTimeText;
      String endTimeText;
      int? reminder = _reminderMinutesBefore;

      if (_allDay) {
        if (_endDate.isBefore(_startDate)) {
          setState(() => _error = l10n.invalidTime);
          return;
        }
        range = _allDayDateRange(_startDate, _endDate);
        startTimeText = '';
        endTimeText = '';
        reminder = null;
      } else {
        final parsed = parsePersonalEventTimes(
          startRaw: _startController.text,
          endRaw: _endController.text,
        );
        if (parsed == null) {
          setState(() => _error = l10n.invalidTime);
          return;
        }

        final startDateTime = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          parsed.start.hour,
          parsed.start.minute,
        );
        DateTime endDateTime;
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
          if (!endDateTime.isAfter(startDateTime)) {
            setState(() => _error = l10n.invalidTime);
            return;
          }
        }
        range = DateTimeRange(start: startDateTime, end: endDateTime);
        startTimeText = formatAlmanacTime(parsed.start);
        endTimeText = parsed.end == null ? '' : formatAlmanacTime(parsed.end!);
      }

      // Overlaps are allowed; warning is shown in the form UI.

      final rrule = _recurrence.rruleString;
      final recurrenceUntil = rrule != null && rrule.isNotEmpty
          ? _recurrenceUntil
          : null;
      final pomodoro = _parsePomodoroMinutes(l10n);
      if (_error != null || pomodoro == null) return;

      final parentShift = !_allDay
          ? resolveParentShiftEvent(
              startMinutes: range.start.hour * 60 + range.start.minute,
              endMinutes: range.end.hour * 60 + range.end.minute,
              dayEvents: widget.existingEvents,
            )
          : null;

      await _persist(
        AppEvent(
          id: id,
          kind: CalendarEntryKind.event,
          dateTimeRange: range,
          title: title,
          startTime: startTimeText,
          endTime: endTimeText,
          color: color,
          checklist: const [],
          rrule: rrule,
          recurrenceUntil: recurrenceUntil,
          seriesId: rrule != null ? id : null,
          parentEventId: parentShift?.id,
          notes: _notesOrNull(),
          reminderMinutesBefore: reminder,
          pomodoroEnabled: _pomodoroEnabled,
          pomodoroWorkMinutes: pomodoro.work,
          pomodoroBreakMinutes: pomodoro.breakMinutes,
          contextProfileId: profileId,
          interaction: EventInteraction.allowNone(),
        ),
      );
      return;
    }

    if (_kind == CalendarEntryKind.note) {
      final notes = _notesController.text.trim();
      if (notes.isEmpty) {
        setState(() => _error = l10n.emptyNoteBody);
        return;
      }

      final incomeAmount = _parseIncomeAmount(l10n);
      if (_error != null) return;

      await _persist(
        AppEvent(
          id: id,
          kind: CalendarEntryKind.note,
          dateTimeRange: AppEvent.dateOnlyRange(_startDate),
          title: _resolveTitle(l10n),
          startTime: '',
          endTime: '',
          color: color,
          notes: notes,
          incomeAmount: incomeAmount,
          isGift: _isGift,
          attachments: _attachments,
          contextProfileId: profileId,
          isUndated: _isUndated,
          interaction: EventInteraction.allowNone(),
        ),
      );
      return;
    }

    _checklistEditorKey.currentState?.commitPendingDraft();

    if (_checklist.isEmpty) {
      setState(() => _error = l10n.emptyChecklistItems);
      return;
    }

    final pomodoro = _parsePomodoroMinutes(l10n);
    if (_error != null || pomodoro == null) return;

    await _persist(
      AppEvent(
        id: id,
        kind: CalendarEntryKind.checklist,
        dateTimeRange: AppEvent.dateOnlyRange(_startDate),
        title: _resolveTitle(l10n),
        startTime: '',
        endTime: '',
        color: color,
        checklist: _checklist,
        pomodoroEnabled: _pomodoroEnabled,
        pomodoroWorkMinutes: pomodoro.work,
        pomodoroBreakMinutes: pomodoro.breakMinutes,
        contextProfileId: profileId,
        isUndated: _isUndated,
        interaction: EventInteraction.allowNone(),
      ),
    );
  }

  Future<void> _persist(AppEvent event) async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onPersist(event);
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

  DateTimeRange _allDayDateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return AppEvent.dateOnlyRange(start);
    }

    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));
    return DateTimeRange(start: rangeStart, end: rangeEnd);
  }
}
