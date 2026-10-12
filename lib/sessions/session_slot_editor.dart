import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/ui/almanac_buttons.dart';
import '../platform/session_types.dart';

/// Dialog to edit a session slot start/end times and optional label.
class SessionSlotEditor {
  SessionSlotEditor._();

  static Future<SessionSlot?> show({
    required BuildContext context,
    SessionSlot? initial,
  }) async {
    final now = DateTime.now();
    var start = initial?.start ?? DateTime(now.year, now.month, now.day, 10);
    var end = initial?.end ?? start.add(const Duration(hours: 1));
    final labelController = TextEditingController(text: initial?.label ?? '');
    final l10n = AppLocalizations.of(context);

    final saved = await showAlmanacSheet<bool>(
      context: context,
      title: initial == null
          ? l10n.slotEditorNewTitle
          : l10n.slotEditorEditTitle,
      size: AlmanacPanelSize.hug,
      compactWidth: true,
      child: StatefulBuilder(
        builder: (context, setState) {
          final locale = Localizations.localeOf(context).toString();
          final formatter = DateFormat('d MMM yyyy, HH:mm', locale);

          Future<void> pickStart() async {
            final date = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date == null) return;
            if (!context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(start),
            );
            if (time == null) return;
            setState(() {
              start = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              if (!end.isAfter(start)) {
                end = start.add(const Duration(hours: 1));
              }
            });
          }

          Future<void> pickEnd() async {
            final date = await showDatePicker(
              context: context,
              initialDate: end,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date == null) return;
            if (!context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(end),
            );
            if (time == null) return;
            setState(() {
              end = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.startTime),
                subtitle: Text(formatter.format(start)),
                trailing: const Icon(Icons.schedule),
                onTap: pickStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.endTime),
                subtitle: Text(formatter.format(end)),
                trailing: const Icon(Icons.schedule),
                onTap: pickEnd,
              ),
              TextField(
                controller: labelController,
                decoration: InputDecoration(labelText: l10n.slotEditorLabel),
              ),
              const SizedBox(height: 12),
              AlmanacDialogActions(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: end.isAfter(start)
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) {
      labelController.dispose();
      return null;
    }

    final label = labelController.text.trim();
    labelController.dispose();
    return SessionSlot(
      id: initial?.id ?? '',
      start: start.toLocal(),
      end: end.toLocal(),
      label: label.isEmpty ? null : label,
    );
  }
}
