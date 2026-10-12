import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/booking_offer.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/profiles/profile_scoped_repositories.dart';
import '../../platform/session_types.dart';
import '../../state/app_providers.dart';
import '../../state/calendar_events_notifier.dart';
import '../../state/session_pending_providers.dart';
import '../../core/ui/almanac_feedback.dart';

Future<void> createRemoteSession({
  required BuildContext context,
  required WidgetRef ref,
  required String profileId,
  required SessionMode mode,
  required String title,
  required List<SessionSlot> slots,
  List<SessionFormField> formFields = const [],
  Map<String, dynamic> settings = const {},
}) async {
  final remote = ref.read(remotePlatformApiProvider);
  final ydbConfigured = ref
      .read(localDataStoreProvider)
      .ydbConnectionStore
      .isConfigured;

  final l10n = AppLocalizations.of(context);
  if (remote == null && !ydbConfigured) {
    AlmanacFeedback.showError(context, l10n.serverUrlRequired);
    return;
  }

  if (remote == null) {
    if (mode != SessionMode.booking) {
      AlmanacFeedback.showError(context, l10n.serverUrlRequired);
      return;
    }
    _publishYdbBookingOffers(
      ref: ref,
      profileId: profileId,
      title: title,
      slots: slots,
      formFields: formFields,
      capacity: settings['slot_capacity'] as int? ?? 1,
    );
    if (context.mounted) {
      AlmanacFeedback.showSuccess(
        context,
        l10n.ydbBookingPublished(slots.length),
      );
    }
    return;
  }

  try {
    final created = await remote.createSessionRemote(
      profileId: profileId,
      mode: mode,
      title: title,
      slots: slots,
      formFields: formFields,
      settings: settings,
    );
    if (!context.mounted) return;
    await Clipboard.setData(ClipboardData(text: created.deepLink));
    if (!context.mounted) return;
    AlmanacFeedback.showSuccess(
      context,
      l10n.linkCopiedWithUrl(created.deepLink),
    );
    ref.invalidate(sessionLinksProvider(profileId));
    ref.invalidate(openBookingSessionsProvider);
  } catch (error) {
    if (context.mounted) {
      AlmanacFeedback.showError(context, error.toString());
    }
  }
}

void _publishYdbBookingOffers({
  required WidgetRef ref,
  required String profileId,
  required String title,
  required List<SessionSlot> slots,
  List<SessionFormField> formFields = const [],
  int capacity = 1,
}) {
  final repo = ProfileScopedEventRepository(
    ref.read(eventRepositoryProvider),
    profileId,
  );
  for (final slot in slots) {
    repo.addEvent(
      BookingOfferEvents.fromSlot(
        slot: slot,
        title: title,
        profileId: profileId,
        capacity: capacity,
        formFields: formFields,
      ),
    );
  }
  ref.read(calendarEventsProvider.notifier).reload();
}
