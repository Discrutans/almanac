import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/almanac_sheets.dart';

/// Быстрые действия по дате (long-press вне month).
class DayDateActionsSheet {
  DayDateActionsSheet._();

  static Future<void> show({
    required BuildContext context,
    required DateTime date,
    required VoidCallback onCreate,
    required VoidCallback onViewDay,
    bool canCreate = true,
  }) {
    final l10n = AppLocalizations.of(context);

    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.dateActionsTitle(date),
      size: AlmanacPanelSize.hug,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canCreate)
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(l10n.createForDayAction),
              onTap: () {
                Navigator.pop(context);
                onCreate();
              },
            ),
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: Text(l10n.viewDayEvents),
            onTap: () {
              Navigator.pop(context);
              onViewDay();
            },
          ),
        ],
      ),
    );
  }
}
