part of 'platform_links_sheet.dart';

class _RemoteSessionsSection extends ConsumerWidget {
  const _RemoteSessionsSection({required this.profileId});

  final String profileId;

  Future<void> _closeSession(
    BuildContext context,
    WidgetRef ref,
    CreateSessionResult session,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.closeSession,
      message: session.title,
      confirmLabel: l10n.closeSession,
      cancelLabel: l10n.cancel,
    );
    if (confirmed != true || !context.mounted) return;

    final remote = ref.read(remotePlatformApiProvider);
    if (remote == null) return;

    try {
      await remote.closeSessionRemote(
        profileId: profileId,
        token: session.token,
      );
      ref.invalidate(sessionLinksProvider(profileId));
      refreshRemoteSessionPending(ref);
      if (context.mounted) {
        AlmanacFeedback.showSuccess(context, l10n.sessionClosed);
      }
    } catch (error) {
      if (context.mounted) {
        AlmanacFeedback.showError(context, error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final remote = ref.watch(remotePlatformApiProvider);
    if (remote == null) return const SizedBox.shrink();

    final sessionsAsync = ref.watch(sessionLinksProvider(profileId));

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.serverSessionsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          sessionsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(
              l10n.serverConnectionFailed(error.toString()),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            data: (sessions) {
              if (sessions.isEmpty) {
                return Text(
                  l10n.noServerSessionsYet,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.almanacColors.muted,
                  ),
                );
              }
              return Column(
                children: sessions
                    .map(
                      (session) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          session.mode == SessionMode.booking
                              ? Icons.schedule
                              : Icons.edit_calendar,
                        ),
                        title: Text(session.title),
                        subtitle: Text(session.deepLink),
                        onTap: () => ref
                            .read(appRouterProvider)
                            .push('/session/${session.token}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new),
                              tooltip: l10n.openSession,
                              onPressed: () => ref
                                  .read(appRouterProvider)
                                  .push('/session/${session.token}'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              tooltip: l10n.linkCopied,
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: session.deepLink),
                                );
                                if (context.mounted) {
                                  AlmanacFeedback.showSuccess(
                                    context,
                                    l10n.linkCopied,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: l10n.closeSession,
                              onPressed: () =>
                                  _closeSession(context, ref, session),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
