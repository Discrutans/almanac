import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_segmented_bar.dart';
import '../../calendar_types.dart';

/// Переключатель режимов календаря.
class CalendarModeSwitcher extends StatelessWidget {
  const CalendarModeSwitcher({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onModeChanged;

  static const _modes = [
    CalendarMode.agenda,
    CalendarMode.week,
    CalendarMode.month,
    CalendarMode.year,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlmanacSegmentedBar<CalendarMode>(
      values: _modes,
      selected: mode,
      onChanged: onModeChanged,
      labelOf: (item) => switch (item) {
        CalendarMode.week => l10n.week,
        CalendarMode.month => l10n.month,
        CalendarMode.agenda => l10n.agenda,
        CalendarMode.year => l10n.year,
      },
    );
  }
}
