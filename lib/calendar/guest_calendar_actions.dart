import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/almanac_http.dart';
import 'ics_import.dart';
import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_feedback.dart';
import '../data/guest/guest_calendar_subscription.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';

/// Добавление read-only подписки на внешний .ics-календарь.
Future<void> subscribeGuestCalendarFromUrl({
  required BuildContext context,
  required WidgetRef ref,
  required String url,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context);

  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) return;

  final client = almanacHttpClient();
  try {
    final response = await client.get(Uri.parse(trimmedUrl));
    if (response.statusCode >= 400) {
      if (context.mounted) {
        AlmanacFeedback.showError(context, l10n.saveFailed(response.body));
      }
      return;
    }

    if (!context.mounted) return;
    final profileId = ref.read(activeProfileIdProvider);
    final fallbackColor = Theme.of(context).colorScheme.secondary;
    final events = IcsCalendarImport.parse(
      response.body,
      fallbackColor: fallbackColor,
    );
    final subscription = GuestCalendarSubscription(
      id: 'guest-${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      title: title.trim().isEmpty ? trimmedUrl : title.trim(),
      url: trimmedUrl,
      subscribedAt: DateTime.now(),
      cachedEvents: events,
    );

    ref.read(localDataStoreProvider).upsertGuestCalendar(subscription);
    ref.read(calendarEventsProvider.notifier).reload();

    if (context.mounted) {
      AlmanacFeedback.showSuccess(context, l10n.guestCalendarAddAction);
    }
  } catch (error) {
    if (context.mounted) {
      AlmanacFeedback.showError(context, l10n.saveFailed(error));
    }
  } finally {
    client.close();
  }
}
