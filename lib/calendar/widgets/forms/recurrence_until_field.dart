import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import 'event_form_sections.dart';

/// Выбор даты окончания серии повторений.
class RecurrenceUntilField extends StatelessWidget {
  const RecurrenceUntilField({
    super.key,
    required this.recurrenceUntil,
    required this.onChanged,
    required this.firstDate,
  });

  final DateTime? recurrenceUntil;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: recurrenceUntil ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime(firstDate.year + 10),
    );
    if (picked == null || !context.mounted) return;
    onChanged(DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = recurrenceUntil == null
        ? l10n.recurrenceUntilClear
        : l10n.fullDate(recurrenceUntil!);

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pickDate(context),
              borderRadius: AlmanacRadius.input,
              child: InputDecorator(
                decoration: eventFormInputDecoration(
                  context,
                  labelText: l10n.recurrenceUntilLabel,
                  suffixIcon: IconButton(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
        if (recurrenceUntil != null) ...[
          const SizedBox(width: AlmanacSpacing.xxs),
          IconButton(
            tooltip: l10n.recurrenceUntilClear,
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.clear_outlined),
          ),
        ],
      ],
    );
  }
}
