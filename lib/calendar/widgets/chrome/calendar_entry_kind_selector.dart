import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_segmented_bar.dart';
import '../../calendar_types.dart';

enum CalendarEntryKindSelectorStyle { segmented, pills }

/// Переключатель типа записи: событие · заметка · чек-лист.
class CalendarEntryKindSelector extends StatelessWidget {
  const CalendarEntryKindSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.style = CalendarEntryKindSelectorStyle.segmented,
  });

  final CalendarEntryKind value;
  final ValueChanged<CalendarEntryKind> onChanged;
  final bool enabled;
  final CalendarEntryKindSelectorStyle style;

  static const _kinds = [
    CalendarEntryKind.event,
    CalendarEntryKind.note,
    CalendarEntryKind.checklist,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showIcons = style == CalendarEntryKindSelectorStyle.segmented;

    return AlmanacSegmentedBar<CalendarEntryKind>(
      values: _kinds,
      selected: value,
      enabled: enabled,
      onChanged: onChanged,
      labelOf: (kind) => switch (kind) {
        CalendarEntryKind.event => l10n.entryKindEvent,
        CalendarEntryKind.note => l10n.entryKindNote,
        CalendarEntryKind.checklist => l10n.entryKindChecklist,
        CalendarEntryKind.savingsGoal => l10n.entryKindSavingsGoal,
      },
      iconOf: showIcons
          ? (kind) => switch (kind) {
              CalendarEntryKind.event => Icons.event_outlined,
              CalendarEntryKind.note => Icons.sticky_note_2_outlined,
              CalendarEntryKind.checklist => Icons.checklist_rtl_outlined,
              CalendarEntryKind.savingsGoal => Icons.savings_outlined,
            }
          : null,
    );
  }
}
