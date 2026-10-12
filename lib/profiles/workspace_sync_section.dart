import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_switch_tile.dart';
import '../data/remote/sync_conflict_dialog.dart';
import '../data/remote/sync_ui_helpers.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';
import '../state/remote_config_providers.dart';

class WorkspaceSyncSection extends ConsumerStatefulWidget {
  const WorkspaceSyncSection();

  @override
  ConsumerState<WorkspaceSyncSection> createState() =>
      _WorkspaceSyncSectionState();
}

class _WorkspaceSyncSectionState extends ConsumerState<WorkspaceSyncSection> {
  String? _lastMessage;
  bool _lastMessageIsError = false;
  bool _syncing = false;

  void _bumpSettings() {
    ref.read(platformSettingsRevisionProvider.notifier).state++;
  }

  void _saveSyncPreferences({
    bool? autoPush,
    bool? autoPull,
    bool? notificationsEnabled,
  }) {
    final profileId = ref.read(activeProfileIdProvider);
    ref
        .read(platformConfigRepositoryProvider)
        .updateSyncPreferences(
          profileId: profileId,
          autoPush: autoPush,
          autoPull: autoPull,
          notificationsEnabled: notificationsEnabled,
        );
    _bumpSettings();
    if (notificationsEnabled != null) {
      ref.read(calendarEventsProvider.notifier).reload();
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _lastMessage = null;
      _lastMessageIsError = false;
    });
    final profileId = ref.read(activeProfileIdProvider);
    final sync = ref.read(remoteSyncServiceProvider);
    var result = await sync.syncAll();
    if (!mounted) return;

    if (result.conflictWithLocal) {
      final choice = await showSyncConflictDialog(context);
      if (choice == SyncConflictChoice.useRemote) {
        result = await resolveSyncConflictPull(
          sync: sync,
          choice: SyncConflictChoice.useRemote,
          onlyProfileId: profileId,
        );
      } else if (choice == SyncConflictChoice.keepLocal) {
        result = await sync.pushLocalChanges(onlyProfileId: profileId);
      }
    }

    if (result.success && result.restoredFromRemote) {
      refreshAfterRemoteRestore(ref);
    }
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastMessage = result.keptLocalAfterConflict
          ? AppLocalizations.of(context).syncKeepLocal
          : result.message;
      _lastMessageIsError = !result.success;
    });
  }

  Future<void> _push({bool allProfiles = false}) async {
    setState(() {
      _syncing = true;
      _lastMessage = null;
      _lastMessageIsError = false;
    });
    final result = await ref
        .read(remoteSyncServiceProvider)
        .pushLocalChanges(
          onlyProfileId: allProfiles ? null : ref.read(activeProfileIdProvider),
          allProfiles: allProfiles,
        );
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastMessage = result.message;
      _lastMessageIsError = !result.success;
    });
  }

  Future<void> _pull({bool allProfiles = false}) async {
    setState(() {
      _syncing = true;
      _lastMessage = null;
      _lastMessageIsError = false;
    });
    var result = await ref
        .read(remoteSyncServiceProvider)
        .pullRemoteChanges(
          forceReplaceLocal: true,
          onlyProfileId: allProfiles ? null : ref.read(activeProfileIdProvider),
        );
    if (!mounted) return;

    if (result.conflictWithLocal) {
      final choice = await showSyncConflictDialog(context);
      if (choice != null) {
        result = await resolveSyncConflictPull(
          sync: ref.read(remoteSyncServiceProvider),
          choice: choice,
          onlyProfileId: allProfiles ? null : ref.read(activeProfileIdProvider),
        );
      }
    }

    if (result.success && result.restoredFromRemote) {
      refreshAfterRemoteRestore(ref);
    }
    setState(() {
      _syncing = false;
      _lastMessage = result.keptLocalAfterConflict
          ? AppLocalizations.of(context).syncKeepLocal
          : result.message;
      _lastMessageIsError = !result.success;
    });
  }

  Future<void> _copyConnectionDetails() async {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(contextProfilesProvider).active;
    final config = ref.read(appConfigProvider);
    final platformConfig = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profile.id);
    final url = platformConfig.serverBaseUrl.isNotEmpty
        ? platformConfig.serverBaseUrl
        : config.serverUrl;
    await Clipboard.setData(
      ClipboardData(
        text: l10n.connectionShareText(
          name: profile.name,
          kind: l10n.profileKindChip(profile.kind, profile.role),
          url: url,
          apiKey: platformConfig.apiKey,
          profileId: profile.id,
        ),
      ),
    );
    if (!mounted) return;
    AlmanacFeedback.showSuccess(context, l10n.connectionDetailsCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(platformSettingsRevisionProvider);
    final config = ref.watch(appConfigProvider);
    final profile = ref.watch(contextProfilesProvider).active;
    final profileId = profile.id;
    final profileName = profile.name;
    final access = profile.access;
    final platformConfig = ref
        .watch(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profileId);
    final hasServer = ref.watch(hasConfiguredServerProvider);
    final syncEnabled = ref.watch(isRemoteSyncConfiguredProvider);
    final linkedCount = ref
        .watch(platformConfigRepositoryProvider)
        .idsSharingConnectionWith(profileId)
        .length;

    String statusText;
    if (!hasServer) {
      statusText = l10n.serverLocalModeStatus;
    } else if (!syncEnabled) {
      statusText = l10n.serverSyncDisabledStatus;
    } else {
      statusText = l10n.serverReadyStatus(profileName);
    }

    final url = platformConfig.serverBaseUrl.isNotEmpty
        ? platformConfig.serverBaseUrl
        : config.serverUrl;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted);

    if (!access.showSyncSettings) {
      return AlmanacCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.serverSectionTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            Text(l10n.personalProfileLocalHint, style: muted),
            const SizedBox(height: AlmanacSpacing.sm),
            AlmanacSwitchTile(
              dense: true,
              value: platformConfig.notificationsEnabled,
              onChanged: (value) =>
                  _saveSyncPreferences(notificationsEnabled: value),
              title: Text(l10n.profileNotificationsLabel),
              subtitle: Text(
                l10n.profileNotificationsHint(profileName),
                style: muted,
              ),
            ),
            if (_lastMessage != null) ...[
              const SizedBox(height: AlmanacSpacing.sm),
              Text(
                _lastMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _lastMessageIsError
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.serverSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          Text(statusText, style: Theme.of(context).textTheme.bodySmall),
          if (hasServer && url.isNotEmpty) ...[
            const SizedBox(height: AlmanacSpacing.xxs),
            Text(url, style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(height: AlmanacSpacing.sm),
          if (access.canShareWorkspaceInvite)
            OutlinedButton.icon(
              onPressed: _syncing ? null : _copyConnectionDetails,
              icon: const Icon(Icons.copy_outlined),
              label: Text(l10n.copyConnectionDetails),
            ),
          if (syncEnabled) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.person_outline, size: 18),
                label: Text(l10n.syncCurrentProfile(profileName)),
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            _SyncActionButton(
              icon: Icons.sync,
              title: l10n.sync,
              hint: l10n.syncNowHint(profileName),
              filled: true,
              busy: _syncing,
              onPressed: _syncing ? null : _syncNow,
            ),
            const SizedBox(height: AlmanacSpacing.xxs),
            Text(
              platformConfig.autoPull
                  ? l10n.autoUpdateOnStatus
                  : l10n.autoUpdateOffStatus,
              style: muted,
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            AlmanacSwitchTile(
              dense: true,
              value: platformConfig.autoPush,
              onChanged: access.canBookOnly
                  ? null
                  : (value) => _saveSyncPreferences(autoPush: value),
              title: Text(l10n.autoPushLabel),
              subtitle: Text(l10n.autoPushHint(profileName), style: muted),
            ),
            AlmanacSwitchTile(
              dense: true,
              value: platformConfig.autoPull,
              onChanged: (value) => _saveSyncPreferences(autoPull: value),
              title: Text(l10n.autoPullLabel),
              subtitle: Text(l10n.autoPullHint(profileName), style: muted),
            ),
          ] else
            const SizedBox(height: AlmanacSpacing.sm),
          AlmanacSwitchTile(
            dense: true,
            value: platformConfig.notificationsEnabled,
            onChanged: (value) =>
                _saveSyncPreferences(notificationsEnabled: value),
            title: Text(l10n.profileNotificationsLabel),
            subtitle: Text(
              l10n.profileNotificationsHint(profileName),
              style: muted,
            ),
          ),
          if (syncEnabled) ...[
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  l10n.manualSyncSection,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                children: [
                  _SyncActionButton(
                    icon: Icons.cloud_upload_outlined,
                    title: l10n.pushThisCalendar,
                    hint: l10n.pushThisCalendarHint(profileName),
                    filled: false,
                    busy: _syncing,
                    onPressed: _syncing ? null : () => _push(),
                  ),
                  const SizedBox(height: AlmanacSpacing.xs),
                  _SyncActionButton(
                    icon: Icons.cloud_download_outlined,
                    title: l10n.pullThisCalendar,
                    hint: l10n.pullThisCalendarHint(profileName),
                    filled: false,
                    busy: _syncing,
                    onPressed: _syncing ? null : () => _pull(),
                  ),
                  if (linkedCount > 1) ...[
                    const SizedBox(height: AlmanacSpacing.md),
                    Text(
                      l10n.syncLinkedSection,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: AlmanacSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _syncing
                                ? null
                                : () => _push(allProfiles: true),
                            child: Text(l10n.pushLinkedCalendars),
                          ),
                        ),
                        const SizedBox(width: AlmanacSpacing.xs),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _syncing
                                ? null
                                : () => _pull(allProfiles: true),
                            child: Text(l10n.pullLinkedCalendars),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (_lastMessage != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              _lastMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _lastMessageIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyncActionButton extends StatelessWidget {
  const _SyncActionButton({
    required this.icon,
    required this.title,
    required this.hint,
    required this.filled,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool filled;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final spinner = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);
    final button = filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: spinner,
            label: Text(title),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: spinner,
            label: Text(title),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: double.infinity, child: button),
        const SizedBox(height: AlmanacSpacing.xxs),
        Text(
          hint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted),
        ),
      ],
    );
  }
}

