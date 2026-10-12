import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_buttons.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_form_panel.dart';
import '../core/ui/almanac_sheets.dart';
import '../platform/session_types.dart';

class BookingOfferFormSheet {
  BookingOfferFormSheet._();

  static Future<Map<String, String>?> show({
    required BuildContext context,
    required List<SessionFormField> fields,
    String? guestName,
  }) {
    if (fields.isEmpty) {
      return Future.value(const <String, String>{});
    }
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<Map<String, String>>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.bookThisSlot,
      size: AlmanacPanelSize.hug,
      builder: (context) =>
          _BookingOfferFormBody(fields: fields, guestName: guestName),
    );
  }
}

class _BookingOfferFormBody extends StatefulWidget {
  const _BookingOfferFormBody({required this.fields, this.guestName});

  final List<SessionFormField> fields;
  final String? guestName;

  @override
  State<_BookingOfferFormBody> createState() => _BookingOfferFormBodyState();
}

class _BookingOfferFormBodyState extends State<_BookingOfferFormBody> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _selectValues;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        if (!field.isSelect)
          field.id: TextEditingController(text: _seedValue(field)),
    };
    _selectValues = {
      for (final field in widget.fields)
        if (field.isSelect && field.options.isNotEmpty)
          field.id: field.options.first,
    };
  }

  String _seedValue(SessionFormField field) {
    if (field.id == 'client_name' ||
        field.label.toLowerCase().contains('имя') ||
        field.label.toLowerCase().contains('name')) {
      return widget.guestName?.trim() ?? '';
    }
    return '';
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final values = <String, String>{};
    for (final field in widget.fields) {
      final raw = field.isSelect
          ? (_selectValues[field.id] ?? '')
          : (_controllers[field.id]?.text ?? '');
      final value = raw.trim();
      if (field.required && value.isEmpty) {
        AlmanacFeedback.showError(context, l10n.bookingFormFieldsRequired);
        return;
      }
      if (value.isNotEmpty) values[field.id] = value;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlmanacFormPanel(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final field in widget.fields) ...[
            if (field.isSelect)
              DropdownButtonFormField<String>(
                initialValue: _selectValues[field.id],
                decoration: InputDecoration(labelText: field.label),
                items: [
                  for (final option in field.options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectValues[field.id] = value);
                },
              )
            else
              TextField(
                controller: _controllers[field.id],
                keyboardType: field.isPhone
                    ? TextInputType.phone
                    : TextInputType.text,
                textCapitalization: field.isPhone
                    ? TextCapitalization.none
                    : TextCapitalization.sentences,
                decoration: InputDecoration(labelText: field.label),
              ),
            const SizedBox(height: AlmanacSpacing.sm),
          ],
        ],
      ),
      actions: SizedBox(
        width: double.infinity,
        height: AlmanacSizes.buttonHeight,
        child: AlmanacAsyncFilledButton(
          label: l10n.bookAppointmentAction,
          onPressed: _submit,
        ),
      ),
    );
  }
}
