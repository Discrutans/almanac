import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/ui/almanac_sheets.dart';
import '../../core/ui/almanac_buttons.dart';
import 'remote_sync_service.dart';

enum SyncConflictChoice { useRemote, keepLocal }

/// Диалог выбора при конфликте локальных и серверных данных.
Future<SyncConflictChoice?> showSyncConflictDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showAlmanacSheet<SyncConflictChoice>(
    context: context,
    title: l10n.syncConflictTitle,
    size: AlmanacPanelSize.hug,
    compactWidth: true,
    child: Text(l10n.syncConflictMessage),
    footer: Builder(
      builder: (dialogContext) {
        return AlmanacDialogActions(
          children: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, SyncConflictChoice.keepLocal),
              child: Text(l10n.syncKeepLocal),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, SyncConflictChoice.useRemote),
              child: Text(l10n.syncUseRemote),
            ),
          ],
        );
      },
    ),
  );
}

/// Применяет принудительную загрузку с сервера после выбора пользователя.
Future<RemoteSyncResult> resolveSyncConflictPull({
  required RemoteSyncService sync,
  required SyncConflictChoice choice,
  String? onlyProfileId,
}) {
  if (choice == SyncConflictChoice.useRemote) {
    return sync.pullRemoteChanges(
      forceReplaceLocal: true,
      onlyProfileId: onlyProfileId,
    );
  }
  return Future.value(
    RemoteSyncResult(success: true, message: '', keptLocalAfterConflict: true),
  );
}
