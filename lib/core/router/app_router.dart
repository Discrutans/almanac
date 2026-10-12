import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import '../../calendar/calendar_screen.dart';
import '../../sessions/session_page.dart';
import '../../state/guest_session_providers.dart';
import '../../state/profile_providers.dart';
import '../../state/core_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../platform/ydb/ydb_invite.dart';
import 'deep_link.dart';

/// Роутер создаётся один раз — без лишних rebuild MaterialApp.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/session/:token',
        name: 'session',
        builder: (context, state) {
          final token = state.pathParameters['token'] ?? '';
          final slotId = state.uri.queryParameters['slot'];
          return SessionPage(
            token: token,
            initialSlotId: slotId == null || slotId.isEmpty ? null : slotId,
          );
        },
      ),
      GoRoute(
        path: '/join/:token',
        name: 'join',
        redirect: (context, state) {
          final token = state.pathParameters['token'];
          return token == null ? null : '/session/$token';
        },
      ),
      GoRoute(
        path: '/book/:token',
        name: 'booking_public',
        redirect: (context, state) {
          final token = state.pathParameters['token'];
          return token == null ? null : '/session/$token';
        },
      ),
      GoRoute(
        path: '/plan/:token',
        name: 'group_plan_public',
        redirect: (context, state) {
          final token = state.pathParameters['token'];
          return token == null ? null : '/session/$token';
        },
      ),
    ],
  );
});

/// Listens for incoming deep links and navigates into session routes.
class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleInitialLink();
    _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleInitialLink() async {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _handleUri(initial);
    }
  }

  void _handleUri(Uri uri) {
    final ydbInvite = parseYdbInvite(uri);
    if (ydbInvite != null) {
      final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
      ref
          .read(contextProfilesProvider.notifier)
          .joinYdb(
            name: ydbInvite.name ?? l10n.joinSharedProfile,
            invite: ydbInvite,
          )
          .then((_) {
            ref.read(platformSettingsRevisionProvider.notifier).state++;
            ref.read(appRouterProvider).go('/');
          })
          .catchError((_) {
            ref.read(appRouterProvider).go('/');
          });
      return;
    }

    final invite = parseWorkspaceInvite(uri);
    if (invite != null) {
      final l10n = AppLocalizations.forLocale(AppLocalizations.fallback);
      try {
        ref
            .read(contextProfilesProvider.notifier)
            .joinShared(
              name: invite.name ?? l10n.joinSharedProfile,
              profileId: invite.profileId,
              kind: invite.kind,
              serverBaseUrl: invite.serverOrigin,
              apiKey: invite.apiKey,
            );
        ref.read(platformSettingsRevisionProvider.notifier).state++;
      } catch (_) {
        // Already joined or invalid — still open calendar.
      }
      ref.read(appRouterProvider).go('/');
      return;
    }

    final link = parseSessionDeepLink(uri);
    if (link == null) return;

    if (link.serverOrigin != null && link.serverOrigin!.isNotEmpty) {
      ref.read(guestSessionServerProvider.notifier).state = link.serverOrigin;
    }

    ref.read(appRouterProvider).go('/session/${link.token}');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
