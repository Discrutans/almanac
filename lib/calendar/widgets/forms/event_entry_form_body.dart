import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_switch_tile.dart';
import '../../../core/ui/almanac_time_field.dart';
import '../../../data/events/recurrence_engine.dart';
import '../../calendar_types.dart';
import '../../note_attachment.dart';
import '../chrome/calendar_entry_kind_selector.dart';
import 'checklist_editor.dart';
import 'event_finance_fields.dart';
import 'event_form_extras.dart';
import 'event_form_sections.dart';
import 'note_attachments_section.dart';
import 'recurrence_until_field.dart';

/// Общие поля формы создания/редактирования записи календаря.
class EventEntryFormBody extends StatelessWidget {
  const EventEntryFormBody({
    super.key,
    required this.kind,
    required this.titleController,
    required this.startController,
    required this.endController,
    required this.notesController,
    required this.incomeController,
    required this.pomodoroWorkController,
    required this.pomodoroBreakController,
    required this.overtimeController,
    required this.unpaidMinutesController,
    required this.selectedColor,
    required this.onColorChanged,
    required this.checklist,
    required this.onChecklistChanged,
    required this.checklistEditorKey,
    required this.attachments,
    required this.onAttachmentsChanged,
    required this.attachmentsEventId,
    required this.onAttachmentsError,
    required this.pomodoroEnabled,
    required this.onPomodoroEnabledChanged,
    required this.recurrence,
    required this.onRecurrenceChanged,
    required this.reminderMinutesBefore,
    required this.onReminderChanged,
    required this.showMoreOptions,
    required this.onToggleMoreOptions,
    this.showKindSelector = false,
    this.onKindChanged,
    this.isScheduleEvent = false,
    this.shiftSkipped = false,
    this.onShiftSkippedChanged,
    this.endTimeOptional = true,
    this.showNotesInMoreOptions = true,
    this.showRecurrence = true,
    this.recurrenceUntil,
    this.onRecurrenceUntilChanged,
    this.recurrenceFirstDate,
    this.customRrule,
    this.isGift = false,
    this.onGiftChanged,
    this.autofocusNote = false,
    this.autofocusTitle = false,
  });

  final CalendarEntryKind kind;
  final TextEditingController titleController;
  final TextEditingController startController;
  final TextEditingController endController;
  final TextEditingController notesController;
  final TextEditingController incomeController;
  final TextEditingController pomodoroWorkController;
  final TextEditingController pomodoroBreakController;
  final TextEditingController overtimeController;
  final TextEditingController unpaidMinutesController;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final List<ChecklistItem> checklist;
  final ValueChanged<List<ChecklistItem>> onChecklistChanged;
  final GlobalKey<ChecklistEditorState> checklistEditorKey;
  final List<NoteAttachment> attachments;
  final ValueChanged<List<NoteAttachment>> onAttachmentsChanged;
  final String attachmentsEventId;
  final ValueChanged<String> onAttachmentsError;
  final bool pomodoroEnabled;
  final ValueChanged<bool> onPomodoroEnabledChanged;
  final RecurrencePreset recurrence;
  final ValueChanged<RecurrencePreset> onRecurrenceChanged;
  final int? reminderMinutesBefore;
  final ValueChanged<int?> onReminderChanged;
  final bool showMoreOptions;
  final VoidCallback onToggleMoreOptions;
  final bool showKindSelector;
  final ValueChanged<CalendarEntryKind>? onKindChanged;
  final bool isScheduleEvent;
  final bool shiftSkipped;
  final ValueChanged<bool>? onShiftSkippedChanged;
  final bool endTimeOptional;
  final bool showNotesInMoreOptions;
  final bool showRecurrence;
  final DateTime? recurrenceUntil;
  final ValueChanged<DateTime?>? onRecurrenceUntilChanged;
  final DateTime? recurrenceFirstDate;
  final String? customRrule;
  final bool isGift;
  final ValueChanged<bool>? onGiftChanged;
  final bool autofocusNote;
  final bool autofocusTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showKindSelector && onKindChanged != null) ...[
          CalendarEntryKindSelector(value: kind, onChanged: onKindChanged!),
          const SizedBox(height: AlmanacSpacing.md),
        ],
        if (kind == CalendarEntryKind.note && !isScheduleEvent) ...[
          TextField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: l10n.notes,
              alignLabelWithHint: true,
            ),
            autofocus: autofocusNote,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: l10n.noteTitleOptional),
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          EventFinanceFields(
            amountController: incomeController,
            isGift: isGift,
            onGiftChanged: onGiftChanged,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          NoteAttachmentsSection(
            eventId: attachmentsEventId,
            attachments: attachments,
            onChanged: onAttachmentsChanged,
            onError: onAttachmentsError,
          ),
        ] else if (kind == CalendarEntryKind.checklist && !isScheduleEvent) ...[
          TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: l10n.title),
            autofocus: autofocusTitle,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          ChecklistEditor(
            key: checklistEditorKey,
            items: checklist,
            onChanged: onChecklistChanged,
          ),
        ] else ...[
          TextField(
            controller: titleController,
            decoration: InputDecoration(labelText: l10n.title),
            autofocus: autofocusTitle,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          AlmanacTimeRangeFields(
            startController: startController,
            endController: endController,
            startLabel: l10n.startTime,
            endLabel: l10n.endTime,
            endOptional: endTimeOptional,
          ),
          if (isScheduleEvent) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: l10n.notes,
                alignLabelWithHint: true,
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            AlmanacSwitchTile(
              title: Text(l10n.shiftSkippedLabel),
              subtitle: Text(
                l10n.shiftSkippedHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              value: shiftSkipped,
              onChanged: onShiftSkippedChanged,
            ),
            if (!shiftSkipped) ...[
              const SizedBox(height: AlmanacSpacing.xs),
              TextField(
                controller: unpaidMinutesController,
                decoration: InputDecoration(
                  labelText: l10n.unpaidMinutesLabel,
                  hintText: l10n.unpaidMinutesHint,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AlmanacSpacing.xs),
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
          if (kind == CalendarEntryKind.event) ...[
            const SizedBox(height: AlmanacSpacing.md),
            EventColorSection(color: selectedColor, onChanged: onColorChanged),
            if (showRecurrence && !isScheduleEvent) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              DropdownButtonFormField<RecurrencePreset>(
                initialValue: recurrence,
                decoration: InputDecoration(labelText: l10n.recurrence),
                items: RecurrencePreset.values
                    .where(
                      (preset) =>
                          preset != RecurrencePreset.custom ||
                          recurrence == RecurrencePreset.custom,
                    )
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
              if (recurrence == RecurrencePreset.custom &&
                  customRrule != null &&
                  customRrule!.isNotEmpty) ...[
                const SizedBox(height: AlmanacSpacing.xs),
                Text(
                  l10n.customRecurrenceHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AlmanacSpacing.xxs),
                SelectableText(
                  customRrule!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
              if (recurrence != RecurrencePreset.none &&
                  recurrence != RecurrencePreset.custom &&
                  onRecurrenceUntilChanged != null &&
                  recurrenceFirstDate != null) ...[
                const SizedBox(height: AlmanacSpacing.sm),
                RecurrenceUntilField(
                  recurrenceUntil: recurrenceUntil,
                  onChanged: onRecurrenceUntilChanged!,
                  firstDate: recurrenceFirstDate!,
                ),
              ],
            ],
            const SizedBox(height: AlmanacSpacing.sm),
            EventMoreOptionsButton(
              expanded: showMoreOptions,
              onPressed: onToggleMoreOptions,
            ),
            if (showMoreOptions) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              EventFormExtras(
                notesController: notesController,
                eventStartTime: startController.text,
                reminderMinutesBefore: reminderMinutesBefore,
                onReminderChanged: onReminderChanged,
                overtimeController: overtimeController,
                showOvertime: false,
                showNotes: showNotesInMoreOptions,
              ),
            ],
          ],
        ],
        if (kind != CalendarEntryKind.event) ...[
          const SizedBox(height: AlmanacSpacing.md),
          EventColorSection(color: selectedColor, onChanged: onColorChanged),
        ],
      ],
    );
  }
}
