part of 'platform_links_sheet.dart';

class _ApiSection extends ConsumerStatefulWidget {
  const _ApiSection({required this.contextProfileId, required this.workspace});

  final String contextProfileId;
  final PlatformConfig workspace;

  @override
  ConsumerState<_ApiSection> createState() => _ApiSectionState();
}

class _ApiSectionState extends ConsumerState<_ApiSection> {
  bool _testing = false;
  bool _saving = false;
  String? _statusMessage;
  bool _statusIsError = false;

  late final TextEditingController _serverUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _profileIdController;
  late final TextEditingController _publicOriginController;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _profileIdController = TextEditingController();
    _publicOriginController = TextEditingController();
    _applyWorkspace(repairPlatformConfig(widget.workspace));
  }

  @override
  void didUpdateWidget(covariant _ApiSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contextProfileId != widget.contextProfileId ||
        oldWidget.workspace.apiKey != widget.workspace.apiKey ||
        oldWidget.workspace.serverBaseUrl != widget.workspace.serverBaseUrl) {
      _syncControllersFromConfig();
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _profileIdController.dispose();
    _publicOriginController.dispose();
    super.dispose();
  }

  void _applyWorkspace(PlatformConfig config) {
    _serverUrlController.text = config.serverBaseUrl.isNotEmpty
        ? normalizeServerUrl(config.serverBaseUrl)
        : '';
    _apiKeyController.text = config.apiKey;
    _profileIdController.text = config.profileId;
    _publicOriginController.text = config.publicOrigin.isNotEmpty
        ? normalizeServerUrl(config.publicOrigin)
        : '';
  }

  void _syncControllersFromConfig() {
    final config = repairPlatformConfig(
      ref
          .read(platformConfigRepositoryProvider)
          .getOrCreateConfig(profileId: widget.contextProfileId),
    );
    final appConfig = ref.read(appConfigProvider);
    _applyWorkspace(config);
    if (_serverUrlController.text.isEmpty && appConfig.serverUrl.isNotEmpty) {
      _serverUrlController.text = normalizeServerUrl(appConfig.serverUrl);
    }
  }

  void _applySettingsRevision() {
    ref.read(platformSettingsRevisionProvider.notifier).state++;
    ref.invalidate(remoteSyncServiceProvider);
    ref.invalidate(sessionLinksProvider(widget.contextProfileId));
  }

  void _persistFromControllers() {
    final serverRaw = _serverUrlController.text.trim();
    final publicRaw = _publicOriginController.text.trim();
    ref
        .read(platformConfigRepositoryProvider)
        .updateConnectionSettings(
          profileId: widget.contextProfileId,
          serverBaseUrl: serverRaw,
          apiKey: _apiKeyController.text,
          workspaceProfileId: _profileIdController.text,
          publicOrigin: publicRaw,
        );
    _applySettingsRevision();
  }

  Future<void> _saveSettings() async {
    final l10n = AppLocalizations.of(context);
    final serverRaw = _serverUrlController.text.trim();
    if (!isValidServerUrl(serverRaw)) {
      setState(() {
        _statusMessage = l10n.invalidServerUrl;
        _statusIsError = true;
      });
      return;
    }

    final publicRaw = _publicOriginController.text.trim();
    if (publicRaw.isNotEmpty && !isValidServerUrl(publicRaw)) {
      setState(() {
        _statusMessage = l10n.invalidServerUrl;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    _persistFromControllers();

    if (!mounted) return;
    setState(() {
      _saving = false;
      _statusMessage = l10n.connectionSettingsSaved;
      _statusIsError = false;
    });
    AlmanacFeedback.showSuccess(context, l10n.connectionSettingsSaved);
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final serverRaw = _serverUrlController.text.trim();
    if (!isValidServerUrl(serverRaw)) {
      setState(() {
        _statusMessage = l10n.invalidServerUrl;
        _statusIsError = true;
      });
      return;
    }

    final publicRaw = _publicOriginController.text.trim();
    if (publicRaw.isNotEmpty && !isValidServerUrl(publicRaw)) {
      setState(() {
        _statusMessage = l10n.invalidServerUrl;
        _statusIsError = true;
      });
      return;
    }

    _persistFromControllers();

    final remote = ref.read(remotePlatformApiProvider);
    if (remote == null) {
      setState(() {
        _statusMessage = AppLocalizations.of(context).serverUrlRequired;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _testing = true;
      _statusMessage = null;
    });

    try {
      await remote.verifyWorkspace(profileId: widget.contextProfileId);
      if (!mounted) return;
      setState(() {
        _testing = false;
        _statusMessage = AppLocalizations.of(context).serverConnectionOk;
        _statusIsError = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _statusMessage = AppLocalizations.of(
          context,
        ).serverConnectionFailed(error.toString());
        _statusIsError = true;
      });
    }
  }

  List<Widget> _guestInviteLines(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    ref.watch(platformSettingsRevisionProvider);
    final controller = ref.watch(miniServerControllerProvider);
    final profile = ref.watch(contextProfilesProvider).active;
    final origin = controller.shareOrigin(profileId: widget.contextProfileId);
    final guestHttp = controller
        .guestHttpInvite(
          profileId: widget.contextProfileId,
          kind: profile.kind,
          name: profile.name,
        )
        ?.toString();
    final guestApp = controller.guestAppInvite(
      profileId: widget.contextProfileId,
      kind: profile.kind,
      name: profile.name,
    );
    if (guestHttp == null && guestApp == null) {
      return const [];
    }
    return [
      const SizedBox(height: AlmanacSpacing.sm),
      if (origin.isNotEmpty && isLoopbackOrLanUrl(origin))
        Text(
          l10n.networkLanOnlyWarning,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      if (guestHttp != null)
        _CopyLine(label: l10n.miniServerGuestLink, value: guestHttp),
      if (guestApp != null)
        _CopyLine(label: l10n.miniServerGuestAppLink, value: guestApp),
    ];
  }

  Future<void> _editPushToken(BuildContext context) async {
    final profileId = widget.contextProfileId;
    final configRepo = ref.read(platformConfigRepositoryProvider);
    final current = configRepo.getOrCreateConfig(profileId: profileId);
    final appConfig = ref.read(appConfigProvider);
    final l10n = AppLocalizations.of(context);
    final token = await showAlmanacPrompt(
      context: context,
      title: l10n.editPushToken,
      label: l10n.pushTokenLabel,
      helperText: l10n.pushTokenHint,
      initialValue: current.pushToken.isNotEmpty
          ? current.pushToken
          : appConfig.pushDeviceToken,
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
    );
    if (token == null || !context.mounted) return;

    configRepo.updatePushToken(profileId: profileId, pushToken: token);
    ref.read(platformSettingsRevisionProvider.notifier).state++;

    if (context.mounted) {
      AlmanacFeedback.showSuccess(context, l10n.pushTokenSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appConfig = ref.watch(appConfigProvider);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.apiConnection,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.sm),
          _ConfigField(
            label: l10n.serverUrlLabel,
            controller: _serverUrlController,
            hintText: appConfig.serverUrl.isNotEmpty
                ? appConfig.serverUrl
                : 'https://api.example.com',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          _ConfigField(label: l10n.apiKeyLabel, controller: _apiKeyController),
          const SizedBox(height: AlmanacSpacing.xs),
          _ConfigField(
            label: l10n.profileIdLabel,
            controller: _profileIdController,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          _ConfigField(
            label: l10n.publicOriginLabel,
            controller: _publicOriginController,
            hintText: l10n.publicOriginHint,
            keyboardType: TextInputType.url,
          ),
          ..._guestInviteLines(context, ref, l10n),
          if (_statusMessage != null) ...[
            const SizedBox(height: AlmanacSpacing.xs),
            Text(
              _statusMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _statusIsError
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: AlmanacSpacing.sm),
          FilledButton.icon(
            onPressed: _saving ? null : _saveSettings,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(l10n.saveConnectionSettings),
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.public_outlined),
            label: Text(l10n.testServerConnection),
          ),
          if (ref.watch(hasConfiguredServerProvider)) ...[
            const SizedBox(height: AlmanacSpacing.xs),
            OutlinedButton.icon(
              onPressed: () => _editPushToken(context),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(l10n.editPushToken),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniServerSection extends ConsumerWidget {
  const _MiniServerSection({required this.contextProfileId});

  final String contextProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.watch(miniServerControllerProvider);
    final info = controller.info;
    if (!controller.supported) {
      return AlmanacCard(
        child: Text(
          l10n.miniServerUnsupported,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.miniServerTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          Text(
            l10n.miniServerHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted),
          ),
          if (controller.running && info != null) ...[
            const SizedBox(height: AlmanacSpacing.sm),
            Text(
              l10n.miniServerRunning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            _CopyLine(label: l10n.miniServerLanUrl, value: info.lanOrigin),
            _CopyLine(
              label: l10n.miniServerLocalUrl,
              value: info.loopbackOrigin,
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            Text(
              l10n.miniServerFirewallHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ],
          if (controller.error != null) ...[
            const SizedBox(height: AlmanacSpacing.xs),
            Text(
              controller.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AlmanacSpacing.sm),
          if (controller.running)
            OutlinedButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      await controller.stop(profileId: contextProfileId);
                      ref
                          .read(platformSettingsRevisionProvider.notifier)
                          .state++;
                      ref.invalidate(sessionLinksProvider(contextProfileId));
                    },
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.miniServerStop),
            )
          else
            FilledButton.icon(
              onPressed: controller.busy
                  ? null
                  : () async {
                      final ok = await controller.start(
                        profileId: contextProfileId,
                      );
                      ref
                          .read(platformSettingsRevisionProvider.notifier)
                          .state++;
                      ref.invalidate(sessionLinksProvider(contextProfileId));
                      if (!context.mounted || !ok) return;
                      final url = controller.shareOrigin(
                        profileId: contextProfileId,
                      );
                      AlmanacFeedback.showSuccess(
                        context,
                        l10n.miniServerStarted(
                          url.isEmpty
                              ? (controller.info?.loopbackOrigin ?? '')
                              : url,
                        ),
                      );
                    },
              icon: controller.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_outlined),
              label: Text(l10n.miniServerStart),
            ),
        ],
      ),
    );
  }
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label\n$value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              AlmanacFeedback.showSuccess(
                context,
                AppLocalizations.of(context).linkCopied,
              );
            }
          },
        ),
      ],
    );
  }
}
