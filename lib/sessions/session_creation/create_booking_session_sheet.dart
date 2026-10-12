import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../calendar/calendar_event_index.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_buttons.dart';
import '../../core/ui/almanac_feedback.dart';
import '../../core/ui/almanac_form_panel.dart';
import '../../core/ui/almanac_sheets.dart';
import '../../platform/session_types.dart';
import '../../state/app_providers.dart';
import 'booking_days_calendar.dart';
import 'booking_slot_generator.dart';
import 'session_creation_service.dart';
import 'session_form_fields_editor.dart';

class CreateBookingSessionSheet {
  CreateBookingSessionSheet._();

  static Future<void> show(BuildContext context, {DateTime? initialDate}) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.createEntryBooking,
      builder: (context) => _CreateBookingSessionSheetBody(
        initialDate: initialDate ?? DateTime.now(),
      ),
    );
  }
}

class _CreateBookingSessionSheetBody extends ConsumerStatefulWidget {
  const _CreateBookingSessionSheetBody({required this.initialDate});

  final DateTime initialDate;

  @override
  ConsumerState<_CreateBookingSessionSheetBody> createState() =>
      _CreateBookingSessionSheetBodyState();
}

class _CreateBookingSessionSheetBodyState
    extends ConsumerState<_CreateBookingSessionSheetBody> {
  final _titleController = TextEditingController();
  late final TextEditingController _durationController;
  late final TextEditingController _capacityController;
  late final TextEditingController _workDaysController;
  late final TextEditingController _restDaysController;
  late final TextEditingController _horizonController;
  late DateTime _startDate;
  late DateTime _focusedMonth;
  var _useShiftSchedule = false;
  final Set<DateTime> _selectedDates = {};
  int _workDays = 2;
  int _restDays = 2;
  int _horizonDays = 30;
  TimeOfDay _windowStart = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _windowEnd = const TimeOfDay(hour: 18, minute: 0);
  int _intervalMinutes = 60;
  var _durationInHours = true;
  int _slotCapacity = 1;
  List<SessionFormField> _formFields = const [];
  bool _creating = false;
  var _didSeedFormFields = false;

  @override
  void initState() {
    super.initState();
    _startDate = calendarDayKey(widget.initialDate);
    if (_startDate.isBefore(calendarDayKey(DateTime.now()))) {
      _startDate = calendarDayKey(DateTime.now());
    }
    _focusedMonth = DateTime(_startDate.year, _startDate.month, 1);
    _durationController = TextEditingController(text: '1');
    _capacityController = TextEditingController(text: '$_slotCapacity');
    _workDaysController = TextEditingController(text: '$_workDays');
    _restDaysController = TextEditingController(text: '$_restDays');
    _horizonController = TextEditingController(text: '$_horizonDays');
    _selectWeekdaysInMonth(_focusedMonth);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSeedFormFields) return;
    _didSeedFormFields = true;
    if (_formFields.isEmpty) {
      final l10n = AppLocalizations.of(context);
      _formFields = [
        SessionFormField(
          id: 'client_name',
          label: l10n.bookingFieldPresetName,
          required: true,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _capacityController.dispose();
    _workDaysController.dispose();
    _restDaysController.dispose();
    _horizonController.dispose();
    super.dispose();
  }

  BookingScheduleKind get _scheduleKind =>
      _useShiftSchedule ? BookingScheduleKind.cycle : BookingScheduleKind.dates;

  DateTime get _configStartDate {
    if (_useShiftSchedule || _selectedDates.isEmpty) return _startDate;
    final sorted = _selectedDates.toList()..sort();
    return sorted.first;
  }

  BookingScheduleConfig _buildConfig() {
    return BookingScheduleConfig(
      startDate: _configStartDate,
      horizonDays: _horizonDays,
      kind: _scheduleKind,
      weekdays: const {},
      workDays: _workDays,
      restDays: _restDays,
      windowStart: _windowStart,
      windowEnd: _windowEnd,
      intervalMinutes: _intervalMinutes,
      dates: {..._selectedDates},
    );
  }

  void _selectWeekdaysInMonth(DateTime month) {
    final today = calendarDayKey(DateTime.now());
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    for (
      var day = first;
      !day.isAfter(last);
      day = day.add(const Duration(days: 1))
    ) {
      final key = calendarDayKey(day);
      if (key.isBefore(today)) continue;
      if (key.weekday >= DateTime.monday && key.weekday <= DateTime.friday) {
        _selectedDates.add(key);
      }
    }
  }

  void _toggleDate(DateTime date) {
    final key = calendarDayKey(date);
    final today = calendarDayKey(DateTime.now());
    if (key.isBefore(today)) return;
    setState(() {
      if (_selectedDates.contains(key)) {
        _selectedDates.remove(key);
      } else {
        _selectedDates.add(key);
      }
    });
  }

  void _applyDurationFromField() {
    final raw = _durationController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return;
    final minutes = _durationInHours ? (value * 60).round() : value.round();
    final next = minutes.clamp(5, 720);
    if (next == _intervalMinutes) return;
    setState(() => _intervalMinutes = next);
  }

  void _setDurationUnit({required bool hours}) {
    if (hours == _durationInHours) return;
    setState(() {
      _durationInHours = hours;
      if (hours) {
        final hoursValue = _intervalMinutes / 60;
        if (hoursValue == hoursValue.roundToDouble()) {
          _durationController.text = '${hoursValue.toInt()}';
        } else {
          _durationController.text = hoursValue
              .toStringAsFixed(2)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
        }
      } else {
        _durationController.text = '$_intervalMinutes';
      }
    });
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _windowStart : _windowEnd,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _windowStart = picked;
      } else {
        _windowEnd = picked;
      }
    });
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AlmanacFeedback.showError(context, l10n.titleRequired);
      return;
    }
    if (_formFields.isEmpty) {
      AlmanacFeedback.showError(context, l10n.bookingFormFieldsRequired);
      return;
    }
    if (_formFields.any((field) => field.isSelect && field.options.isEmpty)) {
      AlmanacFeedback.showError(context, l10n.bookingSelectOptionsRequired);
      return;
    }

    final slots = generateBookingSlots(_buildConfig());
    if (slots.isEmpty) {
      AlmanacFeedback.showError(context, l10n.bookingNoSlotsGenerated);
      return;
    }

    setState(() => _creating = true);
    final profileId = ref.read(activeProfileIdProvider);
    final config = _buildConfig();

    await createRemoteSession(
      context: context,
      ref: ref,
      profileId: profileId,
      mode: SessionMode.booking,
      title: title,
      slots: slots,
      formFields: _formFields,
      settings: {
        'schedule_kind': config.kind.name,
        'dates': config.dates.map((date) => date.toIso8601String()).toList(),
        'work_days': config.workDays,
        'rest_days': config.restDays,
        'horizon_days': config.horizonDays,
        'window_start':
            '${config.windowStart.hour.toString().padLeft(2, '0')}:${config.windowStart.minute.toString().padLeft(2, '0')}',
        'window_end':
            '${config.windowEnd.hour.toString().padLeft(2, '0')}:${config.windowEnd.minute.toString().padLeft(2, '0')}',
        'interval_minutes': config.intervalMinutes,
        'start_date': config.startDate.toIso8601String(),
        'slot_capacity': _slotCapacity,
      },
    );

    if (mounted) {
      setState(() => _creating = false);
      Navigator.pop(context);
    }
  }

  String _previewSamples(List<SessionSlot> slots, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).toString();
    return slots
        .take(3)
        .map((slot) {
          final day = l10n.weekdayShort(slot.start.weekday);
          final time = DateFormat.Hm(locale).format(slot.start);
          return '$day $time';
        })
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final slots = generateBookingSlots(_buildConfig());
    final previewCount = slots.length;
    var step = 0;
    int nextStep() => ++step;

    return Theme(
      data: Theme.of(context).copyWith(
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AlmanacSpacing.sm,
            vertical: 10,
          ),
        ),
      ),
      child: AlmanacFormPanel(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.bookingTitleQuestion,
                hintText: l10n.bookingTitleHint,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _BookingStep(
              number: nextStep(),
              title: l10n.bookingDaysQuestion,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AlmanacSpacing.xs,
                    runSpacing: 0,
                    children: [
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(l10n.bookingCalendarMode),
                        selected: !_useShiftSchedule,
                        onSelected: (_) =>
                            setState(() => _useShiftSchedule = false),
                      ),
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(l10n.bookingShiftSchedule),
                        selected: _useShiftSchedule,
                        onSelected: (_) =>
                            setState(() => _useShiftSchedule = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AlmanacSpacing.xs),
                  if (!_useShiftSchedule) ...[
                    BookingDaysCalendar(
                      compact: true,
                      focusedMonth: _focusedMonth,
                      selectedDates: _selectedDates,
                      onToggleDate: _toggleDate,
                      onPrevMonth: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month - 1,
                          );
                        });
                      },
                      onNextMonth: () {
                        setState(() {
                          _focusedMonth = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month + 1,
                          );
                        });
                      },
                    ),
                    Wrap(
                      spacing: AlmanacSpacing.xs,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(
                              () => _selectWeekdaysInMonth(_focusedMonth),
                            );
                          },
                          child: Text(l10n.bookingSelectWeekdaysInMonth),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            setState(_selectedDates.clear);
                          },
                          child: Text(l10n.bookingClearDates),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            controller: _workDaysController,
                            label: l10n.bookingWorkDays,
                            onChanged: (value) =>
                                setState(() => _workDays = value),
                          ),
                        ),
                        const SizedBox(width: AlmanacSpacing.xs),
                        Expanded(
                          child: _NumberField(
                            controller: _restDaysController,
                            label: l10n.bookingRestDays,
                            onChanged: (value) =>
                                setState(() => _restDays = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AlmanacSpacing.xs),
                    _NumberField(
                      controller: _horizonController,
                      label: l10n.bookingHorizonDaysField,
                      max: 365,
                      onChanged: (value) =>
                          setState(() => _horizonDays = value),
                    ),
                    const SizedBox(height: AlmanacSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _startDate = calendarDayKey(picked));
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        DateFormat('d MMM yyyy', locale).format(_startDate),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _BookingStep(
              number: nextStep(),
              title: l10n.bookingHoursQuestion,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(start: true),
                      child: Text(
                        l10n.bookingTimeFrom(_windowStart.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AlmanacSpacing.xs),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(start: false),
                      child: Text(
                        l10n.bookingTimeTo(_windowEnd.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _BookingStep(
              number: nextStep(),
              title: l10n.bookingDurationQuestion,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: _durationInHours
                            ? l10n.bookingDurationUnitHours
                            : l10n.bookingDurationUnitMinutes,
                      ),
                      onChanged: (_) => _applyDurationFromField(),
                    ),
                  ),
                  const SizedBox(width: AlmanacSpacing.xs),
                  Flexible(
                    child: SegmentedButton<bool>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: [
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.bookingDurationUnitHours),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.bookingDurationUnitMinutes),
                        ),
                      ],
                      selected: {_durationInHours},
                      onSelectionChanged: (value) {
                        _setDurationUnit(hours: value.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _BookingStep(
              number: nextStep(),
              title: l10n.bookingCapacityQuestion,
              child: _NumberField(
                controller: _capacityController,
                label: l10n.bookingSlotCapacity,
                max: 99,
                onChanged: (value) => setState(() => _slotCapacity = value),
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            Text(
              previewCount == 0
                  ? l10n.bookingNoSlotsGenerated
                  : l10n.bookingSlotsPreviewDetail(
                      previewCount,
                      _previewSamples(slots, l10n),
                    ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: previewCount == 0
                    ? scheme.error
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _BookingStep(
              number: nextStep(),
              title: l10n.bookingWhatToAsk,
              child: SessionFormFieldsEditor(
                fields: _formFields,
                showHeading: false,
                onChanged: (fields) => setState(() => _formFields = fields),
              ),
            ),
          ],
        ),
        actions: SizedBox(
          width: double.infinity,
          height: AlmanacSizes.buttonHeight,
          child: AlmanacAsyncFilledButton(
            label: l10n.bookingOpenAction,
            isLoading: _creating,
            onPressed: _create,
          ),
        ),
      ),
    );
  }
}

class _BookingStep extends StatelessWidget {
  const _BookingStep({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '$number.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        child,
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.max,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int> onChanged;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) {
        final parsed = int.tryParse(raw.trim());
        if (parsed == null) return;
        var next = parsed;
        if (next < 1) next = 1;
        if (max != null && next > max!) next = max!;
        onChanged(next);
      },
    );
  }
}
