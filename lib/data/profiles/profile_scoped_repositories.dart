import '../../booking/booking_repository.dart';
import '../../booking/booking_types.dart';
import '../../calendar/calendar_types.dart';
import '../events/event_repository.dart';

/// Обёртка над [EventRepository] для активного профиля.
final class ProfileScopedEventRepository {
  const ProfileScopedEventRepository(this._inner, this.profileId);

  final EventRepository _inner;
  final String profileId;

  List<AppEvent> getMasterEvents() =>
      _inner.getMasterEvents(profileId: profileId);

  List<AppEvent> getEventsForYear(int year) =>
      _inner.getEventsForYear(profileId: profileId, year: year);

  List<AppEvent> getEventsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) => _inner.getEventsForRange(
    profileId: profileId,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );

  List<AppEvent> getUndatedEvents() =>
      _inner.getUndatedEvents(profileId: profileId);

  void addEvent(AppEvent event) =>
      _inner.addEvent(profileId: profileId, event: event);

  void updateEvent({required AppEvent event, required AppEvent updatedEvent}) =>
      _inner.updateEvent(
        profileId: profileId,
        event: event,
        updatedEvent: updatedEvent,
      );

  void deleteEvent(String eventId) =>
      _inner.deleteEvent(profileId: profileId, eventId: eventId);

  void upsertScheduleOverride(AppEvent override) =>
      _inner.upsertScheduleOverride(profileId: profileId, override: override);

  void deleteScheduleOverrides(String scheduleId) => _inner
      .deleteScheduleOverrides(profileId: profileId, scheduleId: scheduleId);
}

/// Обёртка над [BookingRepository] для активного профиля.
final class ProfileScopedBookingRepository {
  const ProfileScopedBookingRepository(this._inner, this.profileId);

  final BookingRepository _inner;
  final String profileId;

  BookingTemplate? findTemplateByToken(String token) =>
      _inner.findTemplateByToken(profileId: profileId, token: token);

  List<BookingSlot> getSlots({
    required String templateToken,
    required DateTime day,
  }) => _inner.getSlots(
    profileId: profileId,
    templateToken: templateToken,
    day: day,
  );

  BookingRequest createRequest({
    required String templateToken,
    required DateTime start,
    required DateTime end,
    required BookingConfirmationMode confirmationMode,
  }) => _inner.createRequest(
    profileId: profileId,
    templateToken: templateToken,
    start: start,
    end: end,
    confirmationMode: confirmationMode,
  );

  BookingRequest updateRequestStatus({
    required String requestId,
    required BookingRequestStatus status,
  }) => _inner.updateRequestStatus(
    profileId: profileId,
    requestId: requestId,
    status: status,
  );

  List<BookingRequest> getPendingRequests() =>
      _inner.getPendingRequests(profileId: profileId);
}

/// Объединяет события из нескольких профилей для split-view календаря.
final class CombinedEventRepository {
  const CombinedEventRepository(this._inner, this.profileIds);

  final EventRepository _inner;
  final Set<String> profileIds;

  List<AppEvent> getEventsForRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final merged = <AppEvent>[];

    for (final profileId in profileIds) {
      final events = _inner.getEventsForRange(
        profileId: profileId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      merged.addAll(
        events.map((event) => event.copyWith(contextProfileId: profileId)),
      );
    }

    merged.sort((a, b) => a.start.compareTo(b.start));
    return merged;
  }

  List<AppEvent> getUndatedEvents() {
    final merged = <AppEvent>[];
    for (final profileId in profileIds) {
      merged.addAll(
        _inner
            .getUndatedEvents(profileId: profileId)
            .map((event) => event.copyWith(contextProfileId: profileId)),
      );
    }
    return merged;
  }

  /// Мастер-события всех видимых профилей (для проверки конфликтов).
  List<AppEvent> getMasterEventsForConflict() {
    final merged = <AppEvent>[];

    for (final profileId in profileIds) {
      merged.addAll(_inner.getMasterEvents(profileId: profileId));
    }

    return merged;
  }
}

/// Pending-бронирования из нескольких профилей.
List<BookingRequest> getPendingRequestsForProfiles(
  BookingRepository repo,
  Set<String> profileIds,
) {
  final pending = <BookingRequest>[];

  for (final profileId in profileIds) {
    pending.addAll(repo.getPendingRequests(profileId: profileId));
  }

  pending.sort((a, b) => a.start.compareTo(b.start));
  return pending;
}
