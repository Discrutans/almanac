import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_switch_tile.dart';
import 'event_form_sections.dart';

/// Необязательная сумма записи — удобно для фрилансеров и разовых оплат.
class EventFinanceFields extends StatelessWidget {
  const EventFinanceFields({
    super.key,
    required this.amountController,
    this.isGift = false,
    this.onGiftChanged,
    this.compact = false,
  });

  final TextEditingController amountController;
  final bool isGift;
  final ValueChanged<bool>? onGiftChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EventFormTextField(
          controller: amountController,
          labelText: l10n.eventAmountFieldLabel,
          hintText: l10n.eventAmountFieldHint,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (onGiftChanged != null) ...[
          AlmanacSwitchTile(
            dense: compact,
            title: Text(
              l10n.incomeGiftLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: compact
                ? null
                : Text(
                    l10n.incomeGiftHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            value: isGift,
            onChanged: onGiftChanged,
          ),
        ],
      ],
    );
  }
}
