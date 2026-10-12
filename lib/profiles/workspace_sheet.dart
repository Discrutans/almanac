import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../state/app_providers.dart';
import '../state/session_pending_providers.dart';
import '../calendar/widgets/chrome/calendar_toolbar.dart';
import 'platform_links_sheet.dart';
import 'workspace_catalog.dart';
import 'workspace_sync_section.dart';

/// Server, sync, API links — отдельно от бытовых Settings.
class WorkspaceSheet extends ConsumerWidget {
  const WorkspaceSheet({super.key});

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.workspaceTitle,
      child: const WorkspaceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final remotePending = ref.watch(remoteSessionPendingListProvider);
    final access = ref.watch(activeProfileAccessProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.workspaceSubtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AlmanacSpacing.md),
        if (access.canSeeOwnerInbox && remotePending.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              PendingBookingsSheet.show(context);
            },
            icon: Badge(
              label: Text('${remotePending.length}'),
              child: const Icon(Icons.inbox_outlined),
            ),
            label: Text(l10n.inboxTooltip),
          ),
        const WorkspaceCatalog(),
        const SizedBox(height: AlmanacSpacing.md),
        const WorkspaceSyncSection(),
        const SizedBox(height: AlmanacSpacing.md),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: AlmanacSpacing.xs),
          title: Text(
            l10n.workspaceAdvancedTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            l10n.workspaceAdvancedHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: const [PlatformLinksSheet()],
        ),
      ],
    );
  }
}
