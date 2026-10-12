import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../../core/theme/almanac_tokens.dart';

/// Выбор новой даты для переноса записи из agenda.
class MoveEventToDateSheet {
  MoveEventToDateSheet._();

  static Future<DateTime?> pick({
    required BuildContext context,
    required DateTime initialDate,
  }) async {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<DateTime>(
      context: context,
      title: l10n.moveEventToDateTitle,
      size: AlmanacPanelSize.hug,
      child: _MoveEventToDateBody(initialDate: initialDate),
    );
  }
}

class _MoveEventToDateBody extends StatefulWidget {
  const _MoveEventToDateBody({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_MoveEventToDateBody> createState() => _MoveEventToDateBodyState();
}

class _MoveEventToDateBodyState extends State<_MoveEventToDateBody> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(l10n.fullDate(_selectedDate)),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedDate),
          child: Text(l10n.moveEventToDate),
        ),
      ],
    );
  }
}
