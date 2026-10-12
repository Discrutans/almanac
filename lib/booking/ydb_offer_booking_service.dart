import '../calendar/calendar_types.dart';
import '../calendar/services/calendar_event_lock_guard.dart';
import '../calendar/services/calendar_event_service.dart';
import '../data/remote/remote_auto_sync.dart';
import '../data/remote/remote_sync_service.dart';
import 'booking_offer.dart';

enum YdbOfferBookStatus { booked, alreadyBooked, taken, locked, missing }

enum YdbOfferCancelStatus { cancelled, locked }

/// Запись и отмена слота YDB: lock, persist, sync. Без UI.
class YdbOfferBookingService {
  const YdbOfferBookingService({
    required this.events,
    required this.lockGuard,
    required this.sync,
    required this.autoSync,
  });

  final CalendarEventService events;
  final CalendarEventLockGuard lockGuard;
  final RemoteSyncService sync;
  final RemoteAutoSyncScheduler autoSync;

  AppEvent? latest(AppEvent offer) {
    final found = events.repoFor(offer).getMasterEvents().where((event) {
      return event.id == offer.id;
    });
    return found.isEmpty ? null : found.first;
  }

  static String displayName({
    required Map<String, String> fields,
    required String fallback,
  }) {
    final named = fields['client_name']?.trim();
    if (named != null && named.isNotEmpty) return named;
    for (final value in fields.values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  Future<YdbOfferBookStatus> book({
    required AppEvent offer,
    required String guestProfileId,
    required String guestName,
    required Map<String, String> fields,
    required String workspaceProfileId,
    required void Function() onEventsChanged,
  }) async {
    if (sync.isEnabled) {
      await sync.pullRemoteChanges(onlyProfileId: workspaceProfileId);
      onEventsChanged();
    }

    final current = latest(offer);
    if (current == null) return YdbOfferBookStatus.missing;

    final state = BookingOfferEvents.readState(current);
    if (state.isBookedBy(guestProfileId, guestName: guestName)) {
      return YdbOfferBookStatus.alreadyBooked;
    }
    if (state.isFull) return YdbOfferBookStatus.taken;

    final lock = await lockGuard.acquire(current.id);
    if (!lock.acquired) return YdbOfferBookStatus.locked;

    try {
      events.updatePersonalEvent(
        source: current,
        updated: BookingOfferEvents.booked(
          offer: current,
          guestProfileId: guestProfileId,
          guestName: guestName,
          fields: fields,
        ),
      );
      if (sync.isEnabled) {
        await autoSync.pushNow(onlyProfileId: workspaceProfileId);
      }
      onEventsChanged();
      return YdbOfferBookStatus.booked;
    } finally {
      await lockGuard.release(current.id);
    }
  }

  Future<YdbOfferCancelStatus> cancelOwn({
    required AppEvent event,
    required String guestProfileId,
    required String workspaceProfileId,
    required void Function() onEventsChanged,
  }) async {
    final lock = await lockGuard.acquire(event.id);
    if (!lock.acquired) return YdbOfferCancelStatus.locked;

    try {
      events.updatePersonalEvent(
        source: event,
        updated: BookingOfferEvents.released(
          event,
          guestProfileId: guestProfileId,
        ),
      );
      if (sync.isEnabled) {
        await autoSync.pushNow(onlyProfileId: workspaceProfileId);
      }
      onEventsChanged();
      return YdbOfferCancelStatus.cancelled;
    } finally {
      await lockGuard.release(event.id);
    }
  }
}
