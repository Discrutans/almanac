import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import 'event_form_sections.dart';
import 'reminder_field.dart';

/// Поля заметок, напоминания и сверхурочных для форм события.
class EventFormExtras extends StatelessWidget {
  const EventFormExtras({
    super.key,
    required this.notesController,
    this.eventStartTime = '',
    required this.reminderMinutesBefore,
    required this.onReminderChanged,
    this.overtimeController,
    this.showOvertime = false,
    this.showNotes = true,
    this.compact = false,
  });

  final TextEditingController notesController;
  final String eventStartTime;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderChanged;
  final TextEditingController? overtimeController;
  final bool showOvertime;
  final bool showNotes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNotes) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          EventFormTextField(
            controller: notesController,
            labelText: l10n.notes,
            minLines: 2,
            maxLines: 4,
            alignLabelWithHint: true,
          ),
        ],
        if (showNotes || !compact) const SizedBox(height: AlmanacSpacing.sm),
        ReminderField(
          eventStartTime: eventStartTime,
          minutesBefore: reminderMinutesBefore,
          onChanged: onReminderChanged,
          compact: compact,
        ),
        if (showOvertime && overtimeController != null) ...[
          const SizedBox(height: AlmanacSpacing.sm),
          TextField(
            controller: overtimeController,
            decoration: InputDecoration(
              labelText: l10n.overtimeFieldLabel,
              hintText: l10n.overtimeFieldHint,
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }
}
