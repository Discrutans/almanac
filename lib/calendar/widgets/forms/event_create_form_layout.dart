import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_switch_tile.dart';
import '../../../data/events/recurrence_engine.dart';
import '../../../data/profiles/context_profile.dart';
import '../../calendar_types.dart';
import '../../note_attachment.dart';
import '../chrome/calendar_entry_kind_selector.dart';
import 'checklist_editor.dart';
import 'event_finance_fields.dart';
import 'event_form_extras.dart';
import 'event_form_sections.dart';
import 'note_attachments_section.dart';
import 'recurrence_until_field.dart';

/// Компактная форма создания записи.
class EventCreateFormLayout extends StatelessWidget {
  const EventCreateFormLayout({
    super.key,
    required this.kind,
    required this.profiles,
    required this.selectedProfileId,
    required this.onProfileChanged,
    required this.titleController,
    required this.startController,
    required this.endController,
    required this.notesController,
    required this.incomeController,
    required this.selectedColor,
    required this.onColorChanged,
    required this.checklist,
    required this.onChecklistChanged,
    required this.checklistEditorKey,
    required this.attachments,
    required this.onAttachmentsChanged,
    required this.attachmentsEventId,
    required this.onAttachmentsError,
    required this.recurrence,
    required this.onRecurrenceChanged,
    required this.recurrenceUntil,
    required this.onRecurrenceUntilChanged,
    required this.recurrenceFirstDate,
    required this.isGift,
    required this.onGiftChanged,
    required this.reminderMinutesBefore,
    required this.onReminderChanged,
    required this.onKindChanged,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.allDay,
    required this.onAllDayChanged,
    required this.onPickDate,
    this.autofocusNote = false,
    this.autofocusTitle = false,
    this.isUndated = false,
    required this.onUndatedChanged,
  });

  final CalendarEntryKind kind;
  final List<ContextProfile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onProfileChanged;
  final TextEditingController titleController;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController notesController;
  final TextEditingController incomeController;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final List<ChecklistItem> checklist;
  final ValueChanged<List<ChecklistItem>> onChecklistChanged;
  final GlobalKey<ChecklistEditorState> checklistEditorKey;
  final List<NoteAttachment> attachments;
  final ValueChanged<List<NoteAttachment>> onAttachmentsChanged;
  final String attachmentsEventId;
  final ValueChanged<String> onAttachmentsError;
  final RecurrencePreset recurrence;
  final ValueChanged<RecurrencePreset> onRecurrenceChanged;
  final DateTime? recurrenceUntil;
  final ValueChanged<DateTime?> onRecurrenceUntilChanged;
  final DateTime recurrenceFirstDate;
  final bool isGift;
  final ValueChanged<bool> onGiftChanged;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderChanged;
  final ValueChanged<CalendarEntryKind> onKindChanged;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final bool allDay;
  final ValueChanged<bool> onAllDayChanged;
  final Future<void> Function({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  })
  onPickDate;
  final bool autofocusNote;
  final bool autofocusTitle;
  final bool isUndated;
  final ValueChanged<bool> onUndatedChanged;

  static const _gap = AlmanacSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kind == CalendarEntryKind.note)
          EventFormTextField(
            controller: notesController,
            labelText: l10n.notes,
            autofocus: autofocusNote,
            minLines: 2,
            maxLines: 5,
            alignLabelWithHint: true,
          )
        else
          EventFormTextField(
            controller: titleController,
            labelText: l10n.title,
            hintText: l10n.addEntryTitleHint,
            autofocus: autofocusTitle,
          ),
        const SizedBox(height: _gap),
        CalendarEntryKindSelector(value: kind, onChanged: onKindChanged),
        const SizedBox(height: _gap),
        EventFormProfilePicker(
          profiles: profiles,
          selectedProfileId: selectedProfileId,
          onChanged: onProfileChanged,
        ),
        if (kind == CalendarEntryKind.event) ...[
          const SizedBox(height: _gap),
          _EventFields(
            l10n: l10n,
            allDay: allDay,
            onAllDayChanged: onAllDayChanged,
            startDate: startDate,
            endDate: endDate,
            onStartDateChanged: onStartDateChanged,
            onEndDateChanged: onEndDateChanged,
            onPickDate: onPickDate,
            startController: startController,
            endController: endController,
            recurrence: recurrence,
            onRecurrenceChanged: onRecurrenceChanged,
            recurrenceUntil: recurrenceUntil,
            onRecurrenceUntilChanged: onRecurrenceUntilChanged,
            recurrenceFirstDate: recurrenceFirstDate,
            reminderMinutesBefore: reminderMinutesBefore,
            onReminderChanged: onReminderChanged,
            selectedColor: selectedColor,
            onColorChanged: onColorChanged,
            notesController: notesController,
          ),
        ] else if (kind == CalendarEntryKind.note) ...[
          const SizedBox(height: _gap),
          AlmanacSwitchTile(
            dense: true,
            title: Text(l10n.undatedEntryLabel),
            subtitle: Text(
              l10n.undatedEntryHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: isUndated,
            onChanged: onUndatedChanged,
          ),
          if (!isUndated) ...[
            const SizedBox(height: _gap),
            EventFormDateTimeRow(
              dateLabel: l10n.dateLabel,
              date: startDate,
              onDateTap: () =>
                  onPickDate(initial: startDate, onChanged: onStartDateChanged),
            ),
          ],
          const SizedBox(height: _gap),
          EventFormTextField(
            controller: titleController,
            labelText: l10n.noteTitleOptional,
          ),
          const SizedBox(height: _gap),
          EventFinanceFields(
            amountController: incomeController,
            isGift: isGift,
            onGiftChanged: onGiftChanged,
            compact: true,
          ),
          const SizedBox(height: _gap),
          NoteAttachmentsSection(
            eventId: attachmentsEventId,
            attachments: attachments,
            onChanged: onAttachmentsChanged,
            onError: onAttachmentsError,
          ),
          const SizedBox(height: _gap),
          EventColorSection(
            color: selectedColor,
            onChanged: onColorChanged,
            compact: true,
          ),
        ] else ...[
          const SizedBox(height: _gap),
          AlmanacSwitchTile(
            dense: true,
            title: Text(l10n.undatedEntryLabel),
            subtitle: Text(
              l10n.undatedEntryHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: isUndated,
            onChanged: onUndatedChanged,
          ),
          if (!isUndated) ...[
            const SizedBox(height: _gap),
            EventFormDateTimeRow(
              dateLabel: l10n.dateLabel,
              date: startDate,
              onDateTap: () =>
                  onPickDate(initial: startDate, onChanged: onStartDateChanged),
            ),
          ],
          const SizedBox(height: _gap),
          ChecklistEditor(
            key: checklistEditorKey,
            items: checklist,
            onChanged: onChecklistChanged,
          ),
          const SizedBox(height: _gap),
          EventColorSection(
            color: selectedColor,
            onChanged: onColorChanged,
            compact: true,
          ),
        ],
      ],
    );
  }
}

class _EventFields extends StatelessWidget {
  const _EventFields({
    required this.l10n,
    required this.allDay,
    required this.onAllDayChanged,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onPickDate,
    required this.startController,
    required this.endController,
    required this.recurrence,
    required this.onRecurrenceChanged,
    required this.recurrenceUntil,
    required this.onRecurrenceUntilChanged,
    required this.recurrenceFirstDate,
    required this.reminderMinutesBefore,
    required this.onReminderChanged,
    required this.selectedColor,
    required this.onColorChanged,
    required this.notesController,
  });

  final AppLocalizations l10n;
  final bool allDay;
  final ValueChanged<bool> onAllDayChanged;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final Future<void> Function({
    required DateTime initial,
    required ValueChanged<DateTime> onChanged,
  })
  onPickDate;
  final TextEditingController startController;
  final TextEditingController endController;
  final RecurrencePreset recurrence;
  final ValueChanged<RecurrencePreset> onRecurrenceChanged;
  final DateTime? recurrenceUntil;
  final ValueChanged<DateTime?> onRecurrenceUntilChanged;
  final DateTime recurrenceFirstDate;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderChanged;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlmanacSwitchTile(
          dense: true,
          title: Text(
            l10n.allDay,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          value: allDay,
          onChanged: onAllDayChanged,
        ),
        EventFormDateTimeRow(
          dateLabel: l10n.startTime,
          date: startDate,
          onDateTap: () =>
              onPickDate(initial: startDate, onChanged: onStartDateChanged),
          timeController: allDay ? null : startController,
          timeLabel: l10n.startTime,
        ),
        const SizedBox(height: EventCreateFormLayout._gap),
        EventFormDateTimeRow(
          dateLabel: l10n.endTime,
          date: endDate,
          onDateTap: () =>
              onPickDate(initial: endDate, onChanged: onEndDateChanged),
          timeController: allDay ? null : endController,
          timeLabel: l10n.endTime,
          timeOptional: true,
        ),
        const SizedBox(height: EventCreateFormLayout._gap),
        EventFormDropdownField<RecurrencePreset>(
          value: recurrence,
          labelText: l10n.recurrence,
          items: RecurrencePreset.values
              .where((preset) => preset != RecurrencePreset.custom)
              .map(
                (preset) => DropdownMenuItem(
                  value: preset,
                  child: Text(l10n.recurrencePresetLabel(preset)),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            onRecurrenceChanged(value);
          },
        ),
        if (recurrence != RecurrencePreset.none) ...[
          const SizedBox(height: EventCreateFormLayout._gap),
          RecurrenceUntilField(
            recurrenceUntil: recurrenceUntil,
            onChanged: onRecurrenceUntilChanged,
            firstDate: recurrenceFirstDate,
          ),
        ],
        if (!allDay) ...[
          const SizedBox(height: EventCreateFormLayout._gap),
          EventFormExtras(
            notesController: notesController,
            eventStartTime: startController.text,
            reminderMinutesBefore: reminderMinutesBefore,
            onReminderChanged: onReminderChanged,
            showNotes: false,
            compact: true,
          ),
        ],
        const SizedBox(height: EventCreateFormLayout._gap),
        EventColorSection(
          compact: true,
          color: selectedColor,
          onChanged: onColorChanged,
        ),
        const SizedBox(height: EventCreateFormLayout._gap),
        EventFormTextField(
          controller: notesController,
          labelText: l10n.notes,
          hintText: l10n.addDescriptionHint,
          minLines: 1,
          maxLines: 4,
          alignLabelWithHint: true,
        ),
      ],
    );
  }
}
