import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_segmented_bar.dart';
import '../core/ui/almanac_sheets.dart';
import '../data/profiles/profile_kind.dart';
import '../platform/ydb/ydb_connect_error.dart';
import '../platform/ydb/ydb_connection_config.dart';
import '../platform/ydb/ydb_invite.dart';
import '../platform/ydb/ydb_snapshot_client.dart';
import '../platform/ydb/ydb_workspace_connection.dart';
import '../state/app_providers.dart';
import 'ydb_setup_guide_page.dart';

enum _CreateStep { home, personal, cloud, cloudDone, join }

/// Создание профиля: устройство, облако или ссылка.
class CreateProfileSheet extends ConsumerStatefulWidget {
  const CreateProfileSheet({super.key});

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      title: l10n.createProfile,
      child: const CreateProfileSheet(),
    );
  }

  @override
  ConsumerState<CreateProfileSheet> createState() => _CreateProfileSheetState();
}

class _CreateProfileSheetState extends ConsumerState<CreateProfileSheet> {
  var _step = _CreateStep.home;
  var _guestKind = ProfileKind.collaborative;
  var _busy = false;
  String? _status;
  var _statusIsError = false;
  String? _invitePacked;
  String? _inviteApp;

  final _name = TextEditingController();
  final _database = TextEditingController();
  final _secret = TextEditingController();
  final _ydbInvite = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _database.dispose();
    _secret.dispose();
    _ydbInvite.dispose();
    super.dispose();
  }

  String get _profileName {
    final l10n = AppLocalizations.of(context);
    final typed = _name.text.trim();
    if (typed.isNotEmpty) return typed;
    return l10n.newProfile;
  }

  void _go(_CreateStep step) {
    setState(() {
      _step = step;
      _status = null;
      _statusIsError = false;
    });
  }

  Future<void> _createPersonal() async {
    ref
        .read(contextProfilesProvider.notifier)
        .create(_profileName, kind: ProfileKind.personal);
    if (mounted) Navigator.of(context).pop();
  }

  YdbWorkspaceConnection _ydbDraft({
    required String apiKey,
    required String profileId,
  }) {
    final parsed = YdbConnectionConfig.parse(
      connectionOrPath: _database.text,
      accessKey: _secret.text,
    );
    return YdbWorkspaceConnection(
      endpoint: parsed.endpoint.isEmpty
          ? YdbConnectionConfig.defaultEndpoint
          : parsed.endpoint,
      database: parsed.database,
      secret: parsed.accessKey,
      workspaceApiKey: apiKey,
      workspaceProfileId: profileId,
      guestKind: _guestKind,
    );
  }

  Future<void> _pickKey() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _secret.text = utf8.decode(bytes).trim();
      _status = AppLocalizations.of(context).ydbKeyLoaded;
      _statusIsError = false;
    });
  }

  Future<void> _createCloud() async {
    final l10n = AppLocalizations.of(context);
    if (kIsWeb) {
      setState(() {
        _status = l10n.ydbUnsupportedWeb;
        _statusIsError = true;
      });
      return;
    }
    if (_database.text.trim().isEmpty) {
      setState(() {
        _status = l10n.createProfileNeedDatabase;
        _statusIsError = true;
      });
      return;
    }
    if (_secret.text.trim().isEmpty) {
      setState(() {
        _status = l10n.createProfileNeedKey;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final probe = _ydbDraft(apiKey: 'pending', profileId: 'default');
      final client = await openYdbSnapshotClient(probe);
      await client.ping();
      await client.close();

      final profile = ref
          .read(contextProfilesProvider.notifier)
          .create(_profileName, kind: ProfileKind.collaborative);
      final config = ref
          .read(platformConfigRepositoryProvider)
          .getOrCreateConfig(profileId: profile.id);
      final connection = _ydbDraft(
        apiKey: config.apiKey,
        profileId: config.profileId.trim().isEmpty
            ? profile.id
            : config.profileId,
      );
      await ref
          .read(localDataStoreProvider)
          .ydbConnectionStore
          .save(connection);
      ref
          .read(platformConfigRepositoryProvider)
          .updateSyncPreferences(
            profileId: profile.id,
            autoPush: true,
            autoPull: true,
          );
      ref.read(platformSettingsRevisionProvider.notifier).state++;

      final invite = YdbWorkspaceInvite(
        connection: connection,
        kind: connection.guestKind,
        name: profile.name,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _invitePacked = encodeYdbInvite(invite);
        _inviteApp = ydbInviteAppLink(invite);
        _step = _CreateStep.cloudDone;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = formatYdbConnectError(error);
        _statusIsError = true;
      });
    }
  }

  Future<void> _joinInvite() async {
    final l10n = AppLocalizations.of(context);
    final parsed = parseYdbInvite(_ydbInvite.text.trim());
    if (parsed == null) {
      setState(() {
        _status = l10n.ydbInviteInvalid;
        _statusIsError = true;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final named = _name.text.trim();
      final invite = named.isEmpty
          ? parsed
          : YdbWorkspaceInvite(
              connection: parsed.connection,
              kind: parsed.kind,
              name: named,
            );
      await ref
          .read(contextProfilesProvider.notifier)
          .joinYdb(name: _profileName, invite: invite);
      ref.read(platformSettingsRevisionProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = error.toString();
        _statusIsError = true;
      });
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AlmanacFeedback.showSuccess(
      context,
      AppLocalizations.of(context).linkCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (_step) {
      _CreateStep.home => _home(l10n),
      _CreateStep.personal => _personal(l10n),
      _CreateStep.cloud => _cloud(l10n),
      _CreateStep.cloudDone => _cloudDone(l10n),
      _CreateStep.join => _join(l10n),
    };
  }

  Widget _home(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceTile(
          title: l10n.createProfileOnDevice,
          subtitle: l10n.createProfileOnDeviceHint,
          icon: Icons.phone_android_outlined,
          onTap: () => _go(_CreateStep.personal),
        ),
        _ChoiceTile(
          title: l10n.createProfileCloud,
          subtitle: l10n.createProfileCloudHint,
          icon: Icons.cloud_outlined,
          onTap: () => _go(_CreateStep.cloud),
        ),
        _ChoiceTile(
          title: l10n.joinSharedProfile,
          subtitle: l10n.createProfileJoinHint,
          icon: Icons.link,
          onTap: () => _go(_CreateStep.join),
        ),
      ],
    );
  }

  Widget _personal(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nameField(l10n),
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton(
          onPressed: _createPersonal,
          child: Text(l10n.createProfile),
        ),
        TextButton(
          onPressed: () => _go(_CreateStep.home),
          child: Text(l10n.createProfileBack),
        ),
      ],
    );
  }

  Widget _cloud(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nameField(l10n),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(
          l10n.ydbGuestModeLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        AlmanacSegmentedBar<ProfileKind>(
          values: const [ProfileKind.collaborative, ProfileKind.booking],
          selected: _guestKind,
          enabled: !_busy,
          labelOf: (kind) => kind == ProfileKind.booking
              ? l10n.ydbModeBooking
              : l10n.ydbModeCollaborative,
          onChanged: (kind) => setState(() => _guestKind = kind),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        Text(
          _guestKind == ProfileKind.booking
              ? l10n.ydbModeBookingHint
              : l10n.ydbModeCollaborativeHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _database,
          enabled: !_busy,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: l10n.ydbDatabaseLabel,
            hintText: l10n.ydbDatabaseHint,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickKey,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(l10n.ydbPickKeyFile),
        ),
        if (_secret.text.trim().isNotEmpty) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          Text(l10n.ydbKeyLoaded, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_status != null) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          Text(
            _status!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _statusIsError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _createCloud,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.createProfileConnect),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const YdbSetupGuidePage(),
                    ),
                  );
                },
          child: Text(l10n.ydbGuide),
        ),
        TextButton(
          onPressed: _busy ? null : () => _go(_CreateStep.home),
          child: Text(l10n.createProfileBack),
        ),
      ],
    );
  }

  Widget _cloudDone(AppLocalizations l10n) {
    final packed = _invitePacked ?? '';
    final app = _inviteApp ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.createProfileShareTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        Text(l10n.createProfileShareHint),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(
          l10n.ydbGuestWarning,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.ydbGuestLink),
          subtitle: Text(packed, maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: packed.isEmpty ? null : () => _copy(packed),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.ydbGuestAppLink),
          subtitle: Text(app, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: app.isEmpty ? null : () => _copy(app),
          ),
        ),
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.createProfileDone),
        ),
      ],
    );
  }

  Widget _join(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _nameField(l10n),
        const SizedBox(height: AlmanacSpacing.sm),
        TextField(
          controller: _ydbInvite,
          enabled: !_busy,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: l10n.ydbInvitePasteLabel),
        ),
        if (_status != null) ...[
          const SizedBox(height: AlmanacSpacing.xs),
          Text(
            _status!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AlmanacSpacing.md),
        FilledButton(
          onPressed: _busy ? null : _joinInvite,
          child: Text(l10n.joinProfileSubmit),
        ),
        TextButton(
          onPressed: _busy ? null : () => _go(_CreateStep.home),
          child: Text(l10n.createProfileBack),
        ),
      ],
    );
  }

  Widget _nameField(AppLocalizations l10n) {
    return TextField(
      controller: _name,
      enabled: !_busy,
      decoration: InputDecoration(labelText: l10n.title),
      textInputAction: TextInputAction.next,
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
        shape: const RoundedRectangleBorder(
          borderRadius: AlmanacFieldLayout.highlightRadius,
        ),
      ),
    );
  }
}
