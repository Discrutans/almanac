import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../data/profiles/profile_kind.dart';
import '../platform/platform_config_repository.dart';
import '../platform/platform_types.dart';
import '../platform/server_url.dart';
import '../platform/session_types.dart';
import '../platform/ydb/ydb_connect_error.dart';
import '../platform/ydb/ydb_connection_config.dart';
import '../platform/ydb/ydb_invite.dart';
import '../platform/ydb/ydb_snapshot_client.dart';
import '../platform/ydb/ydb_workspace_connection.dart';
import '../core/router/app_router.dart';
import '../state/app_providers.dart';
import '../state/remote_config_providers.dart';
import '../state/session_pending_providers.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import 'ydb_setup_guide_page.dart';

part 'platform_links_editor.dart';
part 'platform_links_actions.dart';
part 'platform_links_fields.dart';
part 'platform_links_ydb.dart';

/// Управление публичными ссылками, API-ключом и групповым планированием.
class PlatformLinksSheet extends ConsumerStatefulWidget {
  const PlatformLinksSheet({super.key});

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.platformLinks,
      child: const PlatformLinksSheet(),
    );
  }

  @override
  ConsumerState<PlatformLinksSheet> createState() => _PlatformLinksSheetState();
}

class _PlatformLinksSheetState extends ConsumerState<PlatformLinksSheet> {
  @override
  Widget build(BuildContext context) {
    final profileId = ref.watch(activeProfileIdProvider);
    final api = ref.watch(almanacPlatformApiProvider);
    final workspace = api.getWorkspace(profileId: profileId);
    final l10n = AppLocalizations.of(context);
    final hasRemote = ref.watch(hasConfiguredServerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.platformLinksHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AlmanacSpacing.md),
        _YdbSection(
          contextProfileId: profileId,
          canConfigure: ref
              .watch(activeProfileAccessProvider)
              .canConfigureWorkspace,
        ),
        const SizedBox(height: AlmanacSpacing.md),
        _ApiSection(contextProfileId: profileId, workspace: workspace),
        const SizedBox(height: AlmanacSpacing.md),
        _MiniServerSection(contextProfileId: profileId),
        if (hasRemote) ...[
          const SizedBox(height: AlmanacSpacing.md),
          _RemoteSessionsSection(profileId: profileId),
        ] else ...[
          const SizedBox(height: AlmanacSpacing.md),
          AlmanacCard(
            child: Text(
              l10n.createEntryServerHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
