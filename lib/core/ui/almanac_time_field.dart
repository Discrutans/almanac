import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../localization/app_localizations.dart';
import '../theme/almanac_tokens.dart';

/// Форматирует введённые цифры в HH:mm (двоеточие подставляется автоматически).
class AlmanacTimeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted = _formatDigits(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatDigits(String digits) {
    if (digits.length <= 2) return digits;

    var hours = int.tryParse(digits.substring(0, 2)) ?? 0;
    var minutesPart = digits.substring(2);
    if (hours > 23) hours = 23;

    if (minutesPart.isEmpty) {
      return '${hours.toString().padLeft(2, '0')}:';
    }

    var minutes = int.tryParse(minutesPart) ?? 0;
    if (minutesPart.length >= 2 && minutes > 59) minutes = 59;

    if (minutesPart.length == 1) {
      return '${hours.toString().padLeft(2, '0')}:$minutesPart';
    }

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

/// Разбирает HH:mm, H:mm или строку из 3–4 цифр (930 → 09:30).
TimeOfDay? parseAlmanacTime(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  if (value.contains(':')) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 3) return null;

  if (digits.length == 3) {
    final hour = int.tryParse(digits.substring(0, 1));
    final minute = int.tryParse(digits.substring(1));
    if (hour == null || minute == null) return null;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  final hour = int.tryParse(digits.substring(0, 2));

  final minute = int.tryParse(digits.substring(2));
  if (hour == null || minute == null) return null;
  if (hour > 23 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String formatAlmanacTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

/// Поле времени: только цифры, двоеточие подставляется само; опционально — picker.
class AlmanacTimeField extends StatelessWidget {
  const AlmanacTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.helperText,
    this.readOnly = false,
    this.showPicker = true,
    this.onChanged,
    this.isDense = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? helperText;
  final bool readOnly;
  final bool showPicker;
  final VoidCallback? onChanged;
  final bool isDense;

  Future<void> _pickTime(BuildContext context) async {
    final current = parseAlmanacTime(controller.text);
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    controller.text = formatAlmanacTime(picked);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      style: Theme.of(context).textTheme.bodyMedium,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        AlmanacTimeInputFormatter(),
      ],
      onChanged: readOnly ? null : (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? l10n.timeFieldHint,
        helperText: helperText == null
            ? (isDense ? null : l10n.timeFieldHelper)
            : (helperText!.isEmpty ? null : helperText),
        helperMaxLines: 2,
        suffixIcon: showPicker && !readOnly
            ? IconButton(
                tooltip: l10n.pickTimeTooltip,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => _pickTime(context),
              )
            : null,
      ),
    );
  }
}

/// Два поля времени в одной строке.
class AlmanacTimeRangeFields extends StatelessWidget {
  const AlmanacTimeRangeFields({
    super.key,
    required this.startController,
    required this.endController,
    required this.startLabel,
    required this.endLabel,
    this.readOnly = false,
    this.startReadOnly,
    this.endReadOnly,
    this.endOptional = false,
  });

  final TextEditingController startController;
  final TextEditingController endController;
  final String startLabel;
  final String endLabel;
  final bool readOnly;
  final bool? startReadOnly;
  final bool? endReadOnly;
  final bool endOptional;

  bool get _startLocked => startReadOnly ?? readOnly;
  bool get _endLocked => endReadOnly ?? readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AlmanacTimeField(
            controller: startController,
            label: startLabel,
            readOnly: _startLocked,
          ),
        ),
        const SizedBox(width: AlmanacSpacing.sm),
        Expanded(
          child: AlmanacTimeField(
            controller: endController,
            label: endOptional ? l10n.endTimeOptional : endLabel,
            helperText: endOptional ? l10n.endTimeOptionalHint : null,
            readOnly: _endLocked,
          ),
        ),
      ],
    );
  }
}
