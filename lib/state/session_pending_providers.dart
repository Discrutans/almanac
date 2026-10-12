import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifications/event_reminder_service.dart';
import '../core/localization/app_localizations.dart';
import '../platform/remote_almanac_platform_api.dart';
import '../platform/session_types.dart';
import 'app_providers.dart';

/// Pending booking request from a remote session (self-hosted server).
class RemoteSessionPendingRequest {
  const RemoteSessionPendingRequest({
    required this.sessionToken,
    required this.sessionTitle,
    required this.request,
    required this.formFields,
    required this.slots,
  });

  final String sessionToken;
  final String sessionTitle;
  final SessionBookingRequest request;
  final List<SessionFormField> formFields;
  final List<SessionSlot> slots;
}

final remoteSessionPendingErrorProvider = StateProvider<String?>((ref) => null);

final _remoteSessionPendingLastCountProvider = StateProvider<int>((ref) => 0);

/// Загружает pending-заявки с сервера для активного профиля.
final remoteSessionPendingProvider =
    FutureProvider<List<RemoteSessionPendingRequest>>((ref) async {
      final profileId = ref.watch(activeProfileIdProvider);
      final remote = ref.watch(remotePlatformApiProvider);
      ref.watch(platformSettingsRevisionProvider);

      if (remote == null) {
        ref.read(remoteSessionPendingErrorProvider.notifier).state = null;
        ref.read(_remoteSessionPendingLastCountProvider.notifier).state = 0;
        return const [];
      }

      try {
        final pending = await _fetchPending(remote, profileId);
        ref.read(remoteSessionPendingErrorProvider.notifier).state = null;
        await _maybeNotifyNewRequest(ref, pending);
        return pending;
      } catch (error) {
        ref.read(remoteSessionPendingErrorProvider.notifier).state = error
            .toString();
        return const [];
      }
    });

/// Список pending-заявок с сервера (без AsyncValue в UI).
final remoteSessionPendingListProvider =
    Provider<List<RemoteSessionPendingRequest>>((ref) {
      return ref.watch(remoteSessionPendingProvider).valueOrNull ?? const [];
    });

void refreshRemoteSessionPending(WidgetRef ref) {
  ref.invalidate(remoteSessionPendingProvider);
  ref.invalidate(openBookingSessionsProvider);
}

/// Открытые сессии записи активного профиля (график слотов для участников).
final openBookingSessionsProvider = FutureProvider<List<PlatformSession>>((
  ref,
) async {
  final access = ref.watch(activeProfileAccessProvider);
  if (!access.isBooking) return const [];
  final remote = ref.watch(remotePlatformApiProvider);
  if (remote == null) return const [];
  ref.watch(platformSettingsRevisionProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final sessions = await remote.listSessionsRemote(profileId: profileId);
  return [
    for (final session in sessions)
      if (session.mode == SessionMode.booking &&
          session.isOpen &&
          (session.profileId == profileId || session.profileId == 'default'))
        session,
  ];
});

Future<bool> decideRemoteSessionPending(
  WidgetRef ref, {
  required RemoteSessionPendingRequest item,
  required SessionBookingRequestStatus status,
}) async {
  final remote = ref.read(remotePlatformApiProvider);
  if (remote == null) return false;

  try {
    await remote.decideBookingRequestRemote(
      profileId: ref.read(activeProfileIdProvider),
      token: item.sessionToken,
      requestId: item.request.id,
      status: status,
    );
    ref.invalidate(remoteSessionPendingProvider);
    return true;
  } catch (_) {
    return false;
  }
}

Future<List<RemoteSessionPendingRequest>> _fetchPending(
  RemoteAlmanacPlatformApi remote,
  String profileId,
) async {
  final sessions = await remote.listSessionsRemote(profileId: profileId);

  final pending = <RemoteSessionPendingRequest>[];
  for (final session in sessions) {
    if (session.mode != SessionMode.booking) continue;
    for (final request in session.requests) {
      if (request.status != SessionBookingRequestStatus.pending) continue;
      pending.add(
        RemoteSessionPendingRequest(
          sessionToken: session.token,
          sessionTitle: session.title,
          request: request,
          formFields: session.state.formFields,
          slots: session.state.slots,
        ),
      );
    }
  }
  return pending;
}

Future<void> _maybeNotifyNewRequest(
  Ref ref,
  List<RemoteSessionPendingRequest> pending,
) async {
  final lastCount = ref.read(_remoteSessionPendingLastCountProvider);
  if (pending.length <= lastCount) {
    ref.read(_remoteSessionPendingLastCountProvider.notifier).state =
        pending.length;
    return;
  }

  ref.read(_remoteSessionPendingLastCountProvider.notifier).state =
      pending.length;
  if (pending.isEmpty) return;

  final profileId = ref.read(activeProfileIdProvider);
  final notificationsOn = ref
      .read(platformConfigRepositoryProvider)
      .getOrCreateConfig(profileId: profileId)
      .notificationsEnabled;
  if (!notificationsOn) return;

  final locale = ref.read(appLocaleProvider);

  final l10n = AppLocalizations.forLocale(locale);
  await EventReminderService.instance.showInstant(
    title: l10n.newBookingRequestTitle,
    body: l10n.newBookingRequestNotification(pending.last.sessionTitle),
  );
}
