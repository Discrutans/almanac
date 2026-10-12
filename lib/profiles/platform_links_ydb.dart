part of 'platform_links_sheet.dart';

class _YdbSection extends ConsumerStatefulWidget {
  const _YdbSection({required this.contextProfileId, this.canConfigure = true});

  final String contextProfileId;
  final bool canConfigure;

  @override
  ConsumerState<_YdbSection> createState() => _YdbSectionState();
}

class _YdbSectionState extends ConsumerState<_YdbSection> {
  final _database = TextEditingController();
  final _endpoint = TextEditingController();
  final _secret = TextEditingController();
  var _busy = false;
  String? _status;
  var _statusIsError = false;
  var _guestKind = ProfileKind.collaborative;

  @override
  void initState() {
    super.initState();
    final current = ref.read(localDataStoreProvider).ydbConnectionStore.active;
    if (current != null) {
      _database.text = current.database;
      _endpoint.text = current.endpoint;
      _secret.text = current.secret;
      _guestKind = current.guestKind;
    } else {
      _endpoint.text = YdbConnectionConfig.defaultEndpoint;
      final active = ref.read(contextProfilesProvider).active;
      if (active.kind == ProfileKind.booking) {
        _guestKind = ProfileKind.booking;
      }
    }
  }

  @override
  void dispose() {
    _database.dispose();
    _endpoint.dispose();
    _secret.dispose();
    super.dispose();
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
    final text = utf8.decode(bytes);
    setState(() {
      _secret.text = text.trim();
      _status = AppLocalizations.of(context).ydbKeyLoaded;
      _statusIsError = false;
    });
  }

  YdbWorkspaceConnection _fromFields({String? profileId}) {
    final parsed = YdbConnectionConfig.parse(
      connectionOrPath: _database.text,
      accessKey: _secret.text,
      endpoint: _endpoint.text,
    );
    final id = profileId ?? widget.contextProfileId;
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: id);
    return YdbWorkspaceConnection(
      endpoint: parsed.endpoint,
      database: parsed.database,
      secret: parsed.accessKey,
      workspaceApiKey: config.apiKey,
      workspaceProfileId: config.profileId,
      guestKind: _guestKind,
    );
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final connection = _fromFields();
      final client = await openYdbSnapshotClient(connection);
      await client.ping();
      await client.close();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = AppLocalizations.of(context).ydbTestOk(connection.database);
        _statusIsError = false;
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

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      var profileId = widget.contextProfileId;
      final active = ref.read(contextProfilesProvider).active;
      if (active.id == profileId && active.kind == ProfileKind.personal) {
        profileId = ref
            .read(contextProfilesProvider.notifier)
            .create(
              AppLocalizations.of(context).ydbSharedProfileName,
              kind: ProfileKind.collaborative,
            )
            .id;
      }
      final connection = _fromFields(profileId: profileId);
      final client = await openYdbSnapshotClient(connection);
      await client.ping();
      await client.close();
      await ref
          .read(localDataStoreProvider)
          .ydbConnectionStore
          .save(connection);
      ref
          .read(platformConfigRepositoryProvider)
          .updateSyncPreferences(
            profileId: profileId,
            autoPush: true,
            autoPull: true,
          );
      ref.read(platformSettingsRevisionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = AppLocalizations.of(context).ydbConnected;
        _statusIsError = false;
      });
      AlmanacFeedback.showSuccess(
        context,
        AppLocalizations.of(context).ydbConnected,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = formatYdbConnectError(error);
        _statusIsError = true;
      });
    }
  }

  Future<void> _disconnect() async {
    await ref.read(localDataStoreProvider).ydbConnectionStore.clear();
    ref.read(platformSettingsRevisionProvider.notifier).state++;
    if (!mounted) return;
    setState(() {
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.watch(platformSettingsRevisionProvider);
    if (kIsWeb) {
      return AlmanacCard(
        child: Text(
          l10n.ydbUnsupportedWeb,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final store = ref.watch(localDataStoreProvider).ydbConnectionStore;
    final connected = store.isConfigured;
    final profile = ref.watch(contextProfilesProvider).active;
    final packed = connected && store.active != null
        ? encodeYdbInvite(
            YdbWorkspaceInvite(
              connection: store.active!,
              kind: store.active!.guestKind,
              name: profile.name,
            ),
          )
        : null;
    final invite = packed == null
        ? null
        : YdbWorkspaceInvite(
            connection: store.active!,
            kind: store.active!.guestKind,
            name: profile.name,
          );

    final canConfigure = widget.canConfigure;
    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.ydbTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AlmanacSpacing.xs),
          Text(
            canConfigure ? l10n.ydbHint : l10n.ydbGuestReadOnly,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted),
          ),
          if (canConfigure) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              l10n.ydbGuestModeLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            SegmentedButton<ProfileKind>(
              segments: [
                ButtonSegment(
                  value: ProfileKind.collaborative,
                  label: Text(l10n.ydbModeCollaborative),
                  icon: const Icon(Icons.groups_outlined),
                ),
                ButtonSegment(
                  value: ProfileKind.booking,
                  label: Text(l10n.ydbModeBooking),
                  icon: const Icon(Icons.event_available_outlined),
                ),
              ],
              selected: {_guestKind},
              onSelectionChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _guestKind = value.first);
                    },
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            Text(
              _guestKind == ProfileKind.booking
                  ? l10n.ydbModeBookingHint
                  : l10n.ydbModeCollaborativeHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.sm),
            TextField(
              controller: _database,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.ydbDatabaseLabel,
                hintText: l10n.ydbDatabaseHint,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            TextField(
              controller: _endpoint,
              decoration: InputDecoration(
                labelText: l10n.ydbEndpointLabel,
                hintText: YdbConnectionConfig.defaultEndpoint,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            TextField(
              controller: _secret,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: l10n.ydbSecretLabel),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickKey,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.ydbPickKeyFile),
            ),
          ] else ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              _guestKind == ProfileKind.booking
                  ? l10n.ydbModeBookingHint
                  : l10n.ydbModeCollaborativeHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
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
          if (canConfigure && packed != null && invite != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              l10n.ydbGuestWarning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            _CopyLine(label: l10n.ydbGuestLink, value: packed),
            _CopyLine(
              label: l10n.ydbGuestAppLink,
              value: ydbInviteAppLink(invite),
            ),
          ],
          if (canConfigure) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_done_outlined),
              label: Text(l10n.ydbSave),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            OutlinedButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: Text(l10n.ydbTest),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const YdbSetupGuidePage(),
                  ),
                );
              },
              child: Text(l10n.ydbGuide),
            ),
          ],
          if (connected)
            TextButton(
              onPressed: _busy ? null : _disconnect,
              child: Text(canConfigure ? l10n.ydbDisconnect : l10n.ydbLeave),
            ),
        ],
      ),
    );
  }
}
