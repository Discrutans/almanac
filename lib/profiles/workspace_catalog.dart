import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../booking/booking_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/router/app_router.dart';
import '../core/router/deep_link.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_card.dart';
import '../core/ui/almanac_feedback.dart';
import '../core/ui/almanac_sheets.dart';
import '../data/profiles/profile_kind.dart';
import '../platform/session_types.dart';
import '../sessions/session_creation/create_booking_session_sheet.dart';
import '../sessions/session_creation/create_collaborative_session_sheet.dart';
import '../state/app_providers.dart';
import '../state/remote_config_providers.dart';
import '../state/session_pending_providers.dart';

/// Каталог карточек: семья и коммерция.
class WorkspaceCatalog extends ConsumerWidget {
  const WorkspaceCatalog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workspaceFamilyTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        const _CatalogGrid(
          children: [_FamilyInviteCard(), _FamilyMembersCard()],
        ),
        const SizedBox(height: AlmanacSpacing.md),
        Text(
          l10n.workspaceCommerceTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        const _BookingTypesSection(),
      ],
    );
  }
}

class _CatalogGrid extends StatelessWidget {
  const _CatalogGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AlmanacSpacing.sm;
        final maxW = constraints.maxWidth;
        final twoCol =
            maxW.isFinite && maxW >= 480 && children.length > 1;
        if (!twoCol) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _FamilyInviteCard extends ConsumerWidget {
  const _FamilyInviteCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(activeProfileAccessProvider);
    final hasServer = ref.watch(hasConfiguredServerProvider);

    return AlmanacCard(
      onTap: access.canShareWorkspaceInvite && hasServer
          ? () => _copyInvite(context, ref)
          : null,
      child: Row(
        children: [
          Icon(Icons.link_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AlmanacSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.inviteFamilyAction,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasServer
                      ? l10n.inviteFamilyHint
                      : l10n.inviteFamilyNeedsServer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyInvite(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(contextProfilesProvider).active;
    final config = ref
        .read(platformConfigRepositoryProvider)
        .getOrCreateConfig(profileId: profile.id);
    final appConfig = ref.read(appConfigProvider);
    final url = config.serverBaseUrl.isNotEmpty
        ? config.serverBaseUrl
        : appConfig.serverUrl;
    if (url.isEmpty || config.apiKey.isEmpty) {
      AlmanacFeedback.showError(context, l10n.inviteFamilyNeedsServer);
      return;
    }
    final kind = profile.kind == ProfileKind.personal
        ? ProfileKind.collaborative
        : profile.kind;
    final httpLink = workspaceInviteHttp(
      origin: url,
      apiKey: config.apiKey,
      profileId: profile.id,
      kind: kind,
      name: profile.name,
    ).toString();
    final appLink = workspaceInviteAppLink(
      origin: url,
      apiKey: config.apiKey,
      profileId: profile.id,
      kind: kind,
      name: profile.name,
    );
    await Clipboard.setData(
      ClipboardData(
        text: l10n.familyInviteShareText(
          name: profile.name,
          httpLink: httpLink,
          appLink: appLink,
        ),
      ),
    );
    if (!context.mounted) return;
    AlmanacFeedback.showSuccess(context, l10n.familyInviteCopied);
  }
}

class _FamilyMembersCard extends ConsumerWidget {
  const _FamilyMembersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(contextProfilesProvider);
    final notifier = ref.read(contextProfilesProvider.notifier);
    final canDisableLast = state.visibleProfileIds.length > 1;

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.familyMembersTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            l10n.showTogetherAction,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AlmanacSpacing.xs),
          for (final profile in state.profiles)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(profile.name),
              subtitle: Text(l10n.profileKindChip(profile.kind, profile.role)),
              value: state.visibleProfileIds.contains(profile.id),
              onChanged:
                  !canDisableLast && state.visibleProfileIds.contains(profile.id)
                  ? null
                  : (_) => notifier.toggleVisible(profile.id),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => CreateCollaborativeSessionSheet.show(context),
              icon: const Icon(Icons.groups_outlined),
              label: Text(l10n.createEntryCollaborative),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTypesSection extends ConsumerWidget {
  const _BookingTypesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final access = ref.watch(activeProfileAccessProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final sessionsAsync = ref.watch(sessionLinksProvider(profileId));
    final hasServer = ref.watch(hasConfiguredServerProvider);
    final templates = ref
        .watch(bookingRepositoryProvider)
        .listTemplates(profileId: profileId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (access.canCreateBookingSlots && hasServer)
          Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.sm),
            child: FilledButton.tonalIcon(
              onPressed: () => CreateBookingSessionSheet.show(
                context,
                initialDate: DateTime.now(),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.createBookingTypeAction),
            ),
          ),
        if (sessionsAsync.isLoading) const LinearProgressIndicator(),
        if (sessionsAsync.hasError)
          Text(
            sessionsAsync.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Builder(
          builder: (context) {
            final bookingSessions = [
              for (final session
                  in sessionsAsync.valueOrNull ?? const <CreateSessionResult>[])
                if (session.mode == SessionMode.booking) session,
            ];
            if (templates.isEmpty &&
                bookingSessions.isEmpty &&
                !sessionsAsync.isLoading) {
              return Text(
                l10n.bookingTypeEmpty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.almanacColors.muted,
                ),
              );
            }
            if (templates.isEmpty && bookingSessions.isEmpty) {
              return const SizedBox.shrink();
            }
            return _CatalogGrid(
              children: [
                for (final template in templates)
                  _LocalBookingTypeCard(template: template),
                for (final session in bookingSessions)
                  _BookingTypeCard(session: session),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LocalBookingTypeCard extends ConsumerWidget {
  const _LocalBookingTypeCard({required this.template});

  final BookingTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final origin = ref.watch(publicOriginProvider).replaceAll(RegExp(r'/$'), '');
    final link = origin.isEmpty
        ? '/book/${template.token}'
        : '$origin/book/${template.token}';

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            template.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            l10n.durationMinutes(template.duration.inMinutes),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            link,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  AlmanacFeedback.showSuccess(context, l10n.copyBookingLink);
                }
              },
              child: Text(l10n.copyBookingLink),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTypeCard extends ConsumerWidget {
  const _BookingTypeCard({required this.session});

  final CreateSessionResult session;

  Color? _accent(BuildContext context) {
    final raw = session.accentColor;
    if (raw == null || raw.isEmpty) return null;
    final hex = raw.replaceFirst('#', '');
    try {
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accent = _accent(context);
    final profileId = ref.watch(activeProfileIdProvider);

    return AlmanacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (accent != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: AlmanacRadius.control,
                  ),
                  child: const SizedBox(width: 12, height: 12),
                ),
                const SizedBox(width: AlmanacSpacing.xs),
              ],
              Expanded(
                child: Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (session.durationMinutes != null) ...[
            const SizedBox(height: AlmanacSpacing.xxs),
            Text(
              l10n.durationMinutes(session.durationMinutes!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AlmanacSpacing.xxs),
          Text(
            session.isOpen ? session.deepLink : l10n.bookingTypeClosed,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Wrap(
            spacing: AlmanacSpacing.xs,
            children: [
              TextButton(
                onPressed: () =>
                    ref.read(appRouterProvider).push('/session/${session.token}'),
                child: Text(l10n.openSession),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: session.deepLink));
                  if (context.mounted) {
                    AlmanacFeedback.showSuccess(context, l10n.copyBookingLink);
                  }
                },
                child: Text(l10n.copyBookingLink),
              ),
              if (session.isOpen)
                TextButton(
                  onPressed: () => _close(context, ref, profileId),
                  child: Text(l10n.disableBookingIntake),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    String profileId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.disableBookingIntake,
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
}
