import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';
import '../booking/booking_types.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_feedback.dart';
import '../data/events/event_overlap.dart';
import '../data/profiles/profile_scoped_repositories.dart';
import '../platform/session_types.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';
import '../state/session_pending_providers.dart';

/// Создаёт событие календаря при подтверждении локальной заявки.
void applyConfirmedLocalBookingToCalendar({
  required BuildContext context,
  required WidgetRef ref,
  required BookingRequest request,
  String? templateTitle,
}) {
  final profileId = request.profileId;
  final eventRepo = ProfileScopedEventRepository(
    ref.read(eventRepositoryProvider),
    profileId,
  );

  final start = request.start.toLocal();

  final end = request.end.toLocal();

  final title = _bookingTitle(
    templateTitle: templateTitle,
    notes: request.notes,
    fallback: request.templateToken,
  );

  final newEvent = AppEvent(
    id: AppEvent.bookingEventId(request.id),
    dateTimeRange: DateTimeRange(start: start, end: end),
    title: title,
    startTime:
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
    endTime:
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
    color: Theme.of(context).colorScheme.primary,
    checklist: const [],
    interaction: EventInteraction.allowNone(),
    contextProfileId: profileId,
    notes: request.notes,
  ).taggedWith(CalendarEntrySource.booking);

  _persistBookingEvent(
    context: context,
    ref: ref,
    eventRepo: eventRepo,
    event: newEvent,
  );
}

/// Создаёт событие календаря при подтверждении server session booking.
void applyConfirmedSessionBookingToCalendar({
  required BuildContext context,
  required WidgetRef ref,
  required RemoteSessionPendingRequest item,
}) {
  final profileId = ref.read(activeProfileIdProvider);
  SessionSlot? slot;
  for (final candidate in item.slots) {
    if (candidate.id == item.request.slotId) {
      slot = candidate;
      break;
    }
  }
  if (slot == null) return;

  final eventRepo = ProfileScopedEventRepository(
    ref.read(eventRepositoryProvider),
    profileId,
  );

  final guestName = item.request.fields.values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .firstOrNull;

  final title = guestName != null
      ? '${item.sessionTitle} — $guestName'
      : item.sessionTitle;

  final start = slot.start.toLocal();

  final end = slot.end.toLocal();

  final newEvent = AppEvent(
    id: AppEvent.bookingEventId(item.request.id),
    dateTimeRange: DateTimeRange(start: start, end: end),
    title: title,
    startTime:
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
    endTime:
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
    color: Theme.of(context).colorScheme.primary,
    checklist: const [],
    interaction: EventInteraction.allowNone(),
    contextProfileId: profileId,
  ).taggedWith(CalendarEntrySource.booking);

  _persistBookingEvent(
    context: context,
    ref: ref,
    eventRepo: eventRepo,
    event: newEvent,
  );
}

void _persistBookingEvent({
  required BuildContext context,
  required WidgetRef ref,
  required ProfileScopedEventRepository eventRepo,
  required AppEvent event,
}) {
  final l10n = AppLocalizations.of(context);

  final conflict = hasEventConflict(
    candidateStart: event.start,
    candidateEnd: event.end,
    existingEvents: eventRepo.getMasterEvents(),
  );

  eventRepo.addEvent(event);
  ref.read(calendarEventsProvider.notifier).reload();
  AlmanacFeedback.showSuccess(
    context,
    bookingConfirmationFeedback(
      conflict: conflict,
      eventTitle: event.title,
      l10n: l10n,
    ),
  );
}

/// Feedback after confirming a booking (overlap allowed).
@visibleForTesting
String bookingConfirmationFeedback({
  required bool conflict,
  required String eventTitle,
  required AppLocalizations l10n,
}) {
  return conflict
      ? l10n.bookingConfirmedConflict
      : l10n.bookingConfirmedEvent(eventTitle);
}

String _bookingTitle({
  required String fallback,
  String? templateTitle,
  String? notes,
}) {
  if (templateTitle != null && templateTitle.trim().isNotEmpty) {
    final note = notes?.trim();
    if (note != null && note.isNotEmpty) {
      return '$templateTitle — $note';
    }
    return templateTitle;
  }
  final note = notes?.trim();
  if (note != null && note.isNotEmpty) return note;
  return fallback;
}

extension _FirstOrNullBooking<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
