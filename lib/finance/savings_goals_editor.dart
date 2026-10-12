part of 'savings_goals_sheet.dart';

class _SavingsGoalFormResult {
  const _SavingsGoalFormResult({
    required this.title,
    required this.targetAmount,
    required this.targetDate,
    this.note,
    required this.monthlyLivingExpenses,
    required this.savedAmount,
    required this.colorValue,
  });

  final String title;
  final double targetAmount;
  final DateTime targetDate;
  final String? note;
  final double monthlyLivingExpenses;
  final double savedAmount;
  final int colorValue;
}

class _SavingsGoalFormDialog extends StatefulWidget {
  const _SavingsGoalFormDialog({this.existing, required this.onPersist});

  final SavingsGoal? existing;
  final Future<void> Function(_SavingsGoalFormResult result) onPersist;

  @override
  State<_SavingsGoalFormDialog> createState() => _SavingsGoalFormDialogState();
}

class _SavingsGoalFormDialogState extends State<_SavingsGoalFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _livingController;
  late final TextEditingController _savedController;
  late DateTime _targetDate;
  late int _colorValue;
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing?.targetAmount.toString() ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _livingController = TextEditingController(
      text: existing?.monthlyLivingExpenses == 0
          ? ''
          : existing?.monthlyLivingExpenses.toString(),
    );
    _savedController = TextEditingController(
      text: existing?.savedAmount == 0 ? '' : existing?.savedAmount.toString(),
    );
    _targetDate =
        existing?.targetDate ?? DateTime.now().add(const Duration(days: 180));
    _colorValue = existing?.effectiveColorValue ?? defaultSavingsGoalColorValue;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _livingController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  SavingsPlanSummary? get _preview {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) return null;

    final living =
        double.tryParse(_livingController.text.replaceAll(',', '.')) ?? 0;

    return computeSavingsPlan(
      goal: SavingsGoal(
        id: 'preview',
        profileId: 'preview',
        title: _titleController.text.trim(),
        targetAmount: amount,
        targetDate: _targetDate,
        note: _noteController.text.trim(),
        monthlyLivingExpenses: living,
        createdAt: DateTime.now(),
        colorValue: _colorValue,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final living =
        double.tryParse(_livingController.text.replaceAll(',', '.')) ?? 0;
    final saved =
        double.tryParse(_savedController.text.replaceAll(',', '.')) ?? 0;
    final note = _noteController.text.trim();

    if (title.isEmpty) {
      setState(() => _error = l10n.savingsGoalTitleRequired);
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = l10n.savingsGoalAmountRequired);
      return;
    }
    if (living < 0) {
      setState(() => _error = l10n.savingsGoalLivingInvalid);
      return;
    }
    if (saved < 0) {
      setState(() => _error = l10n.savingsGoalLivingInvalid);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onPersist(
        _SavingsGoalFormResult(
          title: title,
          targetAmount: amount,
          targetDate: DateTime(
            _targetDate.year,
            _targetDate.month,
            _targetDate.day,
          ),
          note: note.isEmpty ? null : note,
          monthlyLivingExpenses: living,
          savedAmount: saved,
          colorValue: _colorValue,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = l10n.saveFailed(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final preview = _preview;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: l10n.savingsGoalTitleLabel),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _savedController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.savingsGoalSavedLabel),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.savingsGoalAmountLabel),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        InkWell(
          onTap: _pickDate,
          borderRadius: AlmanacRadius.input,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.savingsGoalDateLabel,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(DateFormat.yMMMd(locale).format(_targetDate)),
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(l10n.color, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AlmanacSpacing.xs),
        AlmanacMiniColorPicker(
          color: Color(_colorValue),
          onChanged: (color) => setState(() => _colorValue = color.toARGB32()),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: l10n.savingsGoalNoteLabel,
            hintText: l10n.savingsGoalNoteHint,
            alignLabelWithHint: true,
          ),
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _livingController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
          ],
          decoration: InputDecoration(
            labelText: l10n.savingsGoalLivingLabel,
            helperText: l10n.savingsGoalLivingHint,
            helperMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (preview != null) ...[
          const SizedBox(height: AlmanacSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AlmanacSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: AlmanacRadius.control,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.savingsGoalPreviewTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AlmanacSpacing.xs),
                Text(
                  preview.isOverdue
                      ? l10n.savingsGoalOverdueHint
                      : l10n.savingsGoalDaysLeft(preview.daysRemaining),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: preview.isOverdue ? scheme.error : null,
                  ),
                ),
                const SizedBox(height: AlmanacSpacing.xxs),
                Text(
                  l10n.savingsGoalMonthlyPayment(
                    formatMoney(preview.monthlySavingsNeeded),
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (preview.monthlyLivingExpenses > 0) ...[
                  const SizedBox(height: AlmanacSpacing.xxs),
                  Text(
                    l10n.savingsGoalMonthlyBudget(
                      formatMoney(preview.totalMonthlyBudget),
                      formatMoney(preview.monthlyLivingExpenses),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: AlmanacSpacing.md),
        AlmanacDialogActions(
          children: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            AlmanacAsyncFilledButton(
              label: l10n.save,
              isLoading: _isSaving,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
