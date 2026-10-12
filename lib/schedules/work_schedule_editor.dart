part of 'work_schedule_sheet.dart';

class _ScheduleFormResult {
  const _ScheduleFormResult({
    required this.title,
    required this.kind,
    required this.rrule,
    required this.cycleStartDate,
    required this.workDays,
    required this.restDays,
    required this.startTime,
    required this.endTime,
    required this.color,
    this.payMode = PayRateMode.hourly,
    this.hourlyRate,
    this.dailyRate,
    this.monthlyRate,
    this.standardHoursPerShift = 8,
    this.overtimeMultiplier = 1.5,
    this.breakMinutes = 0,
    this.bonusPercent,
    this.bonusAmount,
    this.vatPercent,
  });

  final String title;
  final CyclicScheduleKind kind;
  final String rrule;
  final DateTime? cycleStartDate;
  final int workDays;
  final int restDays;
  final String startTime;
  final String endTime;
  final Color color;
  final PayRateMode payMode;
  final double? hourlyRate;
  final double? dailyRate;
  final double? monthlyRate;
  final double standardHoursPerShift;
  final double overtimeMultiplier;
  final int breakMinutes;
  final double? bonusPercent;
  final double? bonusAmount;
  final double? vatPercent;
}

class _ScheduleFormDialog extends StatefulWidget {
  const _ScheduleFormDialog({this.existing, required this.onPersist});

  final CyclicWorkSchedule? existing;
  final Future<void> Function(_ScheduleFormResult result) onPersist;

  @override
  State<_ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<_ScheduleFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _customWorkController;
  late final TextEditingController _customRestController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _dailyRateController;
  late final TextEditingController _monthlyRateController;
  late final TextEditingController _standardHoursController;
  late final TextEditingController _overtimeMultiplierController;
  late final TextEditingController _breakMinutesController;
  late final TextEditingController _bonusPercentController;
  late final TextEditingController _bonusAmountController;
  late final TextEditingController _vatPercentController;

  late DateTime _cycleStartDate;
  late Color _selectedColor;
  late PayRateMode _payMode;
  String? _error;
  bool _isSaving = false;
  var _defaultTitleApplied = false;

  static const _defaultBreakMinutes = 60;

  bool get _isEditing => widget.existing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_defaultTitleApplied) return;
    _defaultTitleApplied = true;
    if (widget.existing == null && _titleController.text.isEmpty) {
      _titleController.text = AppLocalizations.of(context).defaultShiftTitle;
    }
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _startController = TextEditingController(text: existing?.startTime ?? '');
    _endController = TextEditingController(text: existing?.endTime ?? '');
    _customWorkController = TextEditingController(
      text: '${existing?.workDays ?? 2}',
    );
    _customRestController = TextEditingController(
      text: '${existing?.restDays ?? 2}',
    );
    _hourlyRateController = TextEditingController(
      text: existing?.hourlyRate?.toString() ?? '',
    );
    _dailyRateController = TextEditingController(
      text: existing?.dailyRate?.toString() ?? '',
    );
    _monthlyRateController = TextEditingController(
      text: existing?.monthlyRate?.toString() ?? '',
    );
    _standardHoursController = TextEditingController(
      text: '${existing?.standardHoursPerShift ?? 8}',
    );
    _overtimeMultiplierController = TextEditingController(
      text: '${existing?.overtimeMultiplier ?? 1.5}',
    );
    _breakMinutesController = TextEditingController(
      text: '${existing?.breakMinutes ?? _defaultBreakMinutes}',
    );
    _bonusPercentController = TextEditingController(
      text: existing?.bonusPercent?.toString() ?? '',
    );
    _bonusAmountController = TextEditingController(
      text: existing?.bonusAmount?.toString() ?? '',
    );
    _vatPercentController = TextEditingController(
      text: existing?.vatPercent?.toString() ?? '',
    );

    _cycleStartDate = existing?.cycleStartDate ?? DateTime.now();
    _selectedColor = Color(existing?.colorValue ?? Colors.teal.toARGB32());
    _payMode = existing?.payMode ?? PayRateMode.hourly;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startController.dispose();
    _endController.dispose();
    _customWorkController.dispose();
    _customRestController.dispose();
    _hourlyRateController.dispose();
    _dailyRateController.dispose();
    _monthlyRateController.dispose();
    _standardHoursController.dispose();
    _overtimeMultiplierController.dispose();
    _breakMinutesController.dispose();
    _bonusPercentController.dispose();
    _bonusAmountController.dispose();
    _vatPercentController.dispose();
    super.dispose();
  }

  int get _workDays => int.tryParse(_customWorkController.text) ?? 2;

  int get _restDays => int.tryParse(_customRestController.text) ?? 2;

  int get _shiftHolidayCount {
    final now = DateTime.now();
    return countShiftDaysOnHolidays(
      cycleStartDate: _cycleStartDate,
      workDays: _workDays,
      restDays: _restDays,
      from: now,
      to: now.add(const Duration(days: 90)),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _cycleStartDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: Localizations.localeOf(context),
    );
    if (picked != null) {
      setState(() => _cycleStartDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateLabel = DateFormat('dd.MM.yyyy').format(_cycleStartDate);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: l10n.title),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        OutlinedButton.icon(
          onPressed: _pickStartDate,
          icon: const Icon(Icons.event),
          label: Text(l10n.cycleStartDate(dateLabel)),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customWorkController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.workDaysLabel),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/'),
            ),
            Expanded(
              child: TextField(
                controller: _customRestController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: l10n.restDaysLabel),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cycleSummary(_workDays, _restDays),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_shiftHolidayCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            l10n.shiftHolidayWarning(_shiftHolidayCount),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AlmanacSpacing.sm),
        AlmanacTimeRangeFields(
          startController: _startController,
          endController: _endController,
          startLabel: l10n.shiftStartLabel,
          endLabel: l10n.shiftEndLabel,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _breakMinutesController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.breakMinutesLabel),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(
          l10n.paySection,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        DropdownButtonFormField<PayRateMode>(
          initialValue: _payMode,
          decoration: InputDecoration(labelText: l10n.payRateType),
          items: PayRateMode.values
              .map(
                (mode) => DropdownMenuItem(
                  value: mode,
                  child: Text(l10n.payRateLabel(mode)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _payMode = value);
          },
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        if (_payMode == PayRateMode.hourly)
          TextField(
            controller: _hourlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.hourlyRateLabel),
          ),
        if (_payMode == PayRateMode.daily) ...[
          TextField(
            controller: _dailyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.dailyRateLabel),
          ),
          TextField(
            controller: _hourlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.overtimeHourlyRateLabel,
            ),
          ),
        ],
        if (_payMode == PayRateMode.monthly)
          TextField(
            controller: _monthlyRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.monthlyRateLabel),
          ),
        const SizedBox(height: AlmanacSpacing.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _standardHoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.standardHoursLabel),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Expanded(
              child: TextField(
                controller: _overtimeMultiplierController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.overtimeMultiplierLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        Text(
          l10n.overtimeMultiplierHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(
          l10n.payExtrasSection,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        TextField(
          controller: _bonusAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.bonusAmountLabel,
            helperText: l10n.bonusAmountHint,
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        TextField(
          controller: _bonusPercentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.bonusPercentLabel,
            helperText: l10n.bonusPercentHint,
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        TextField(
          controller: _vatPercentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.vatPercentLabel,
            helperText: l10n.vatPercentHint,
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(l10n.color, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AlmanacSpacing.xs),
        AlmanacMiniColorPicker(
          color: _selectedColor,
          onChanged: (color) => setState(() => _selectedColor = color),
        ),
        const SizedBox(height: AlmanacSpacing.md),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: AlmanacSpacing.sm),
        ],
        AlmanacDialogActions(
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            AlmanacAsyncFilledButton(
              label: _isEditing ? l10n.save : l10n.add,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    if (_workDays <= 0 || _restDays <= 0) {
      setState(() => _error = AppLocalizations.of(context).invalidShiftDays);
      return;
    }

    final start = parseAlmanacTime(_startController.text);
    final end = parseAlmanacTime(_endController.text);
    if (start == null || end == null || !end.isAfter(start)) {
      setState(() => _error = AppLocalizations.of(context).invalidTime);
      return;
    }

    final result = _ScheduleFormResult(
      title: _titleController.text.trim(),
      kind: CyclicScheduleKind.shiftCycle,
      rrule: '',
      cycleStartDate: DateTime(
        _cycleStartDate.year,
        _cycleStartDate.month,
        _cycleStartDate.day,
      ),
      workDays: _workDays,
      restDays: _restDays,
      startTime: formatAlmanacTime(start),
      endTime: formatAlmanacTime(end),
      color: _selectedColor,
      payMode: _payMode,
      hourlyRate: double.tryParse(
        _hourlyRateController.text.replaceAll(',', '.'),
      ),
      dailyRate: double.tryParse(
        _dailyRateController.text.replaceAll(',', '.'),
      ),
      monthlyRate: double.tryParse(
        _monthlyRateController.text.replaceAll(',', '.'),
      ),
      standardHoursPerShift:
          double.tryParse(_standardHoursController.text.replaceAll(',', '.')) ??
          8,
      overtimeMultiplier:
          double.tryParse(
            _overtimeMultiplierController.text.replaceAll(',', '.'),
          ) ??
          1.5,
      breakMinutes:
          int.tryParse(_breakMinutesController.text) ?? _defaultBreakMinutes,
      bonusPercent: double.tryParse(
        _bonusPercentController.text.replaceAll(',', '.'),
      ),
      bonusAmount: double.tryParse(
        _bonusAmountController.text.replaceAll(',', '.'),
      ),
      vatPercent: double.tryParse(
        _vatPercentController.text.replaceAll(',', '.'),
      ),
    );

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onPersist(result);
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
}
