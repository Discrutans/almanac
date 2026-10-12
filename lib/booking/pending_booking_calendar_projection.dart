import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import '../booking/booking_types.dart';
import '../calendar/calendar_types.dart';
import '../platform/session_types.dart';
import '../state/session_pending_providers.dart';

/// Проецирует pending-заявки на бронирование в календарь (эфемерные маркеры).
final class PendingBookingCalendarProjection {
  PendingBookingCalendarProjection._();

  static List<AppEvent> expandForProfiles({
    required Iterable<BookingRequest> localPending,
    required Iterable<RemoteSessionPendingRequest> remotePending,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Color? defaultColor,
  }) {
    final events = <AppEvent>[];

    for (final request in localPending) {
      if (request.status != BookingRequestStatus.pending) continue;
      final event = _fromLocalRequest(request, defaultColor: defaultColor);
      if (_intersectsRange(event, rangeStart, rangeEnd)) {
        events.add(event);
      }
    }

    for (final item in remotePending) {
      if (item.request.status != SessionBookingRequestStatus.pending) continue;
      final event = _fromRemoteRequest(item, defaultColor: defaultColor);
      if (event != null && _intersectsRange(event, rangeStart, rangeEnd)) {
        events.add(event);
      }
    }

    return events;
  }

  static AppEvent _fromLocalRequest(
    BookingRequest request, {
    Color? defaultColor,
  }) {
    final start = request.start.toLocal();
    final end = request.end.toLocal();
    final title = request.notes?.trim().isNotEmpty == true
        ? request.notes!.trim()
        : request.templateToken;

    return AppEvent(
      id: AppEvent.pendingBookingEventId(request.id),
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      color: defaultColor ?? Colors.orange,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
      contextProfileId: request.profileId,
      notes: request.notes,
    ).taggedWith(CalendarEntrySource.bookingPending);
  }

  static AppEvent? _fromRemoteRequest(
    RemoteSessionPendingRequest item, {
    Color? defaultColor,
  }) {
    SessionSlot? slot;
    for (final candidate in item.slots) {
      if (candidate.id == item.request.slotId) {
        slot = candidate;
        break;
      }
    }
    if (slot == null) return null;

    final guestName = item.request.fields.values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final title = guestName != null
        ? '${item.sessionTitle} — $guestName'
        : item.sessionTitle;

    final start = slot.start.toLocal();
    final end = slot.end.toLocal();

    return AppEvent(
      id: AppEvent.pendingBookingEventId(item.request.id),
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      color: defaultColor ?? Colors.orange,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
    ).taggedWith(CalendarEntrySource.bookingPending);
  }

  static bool _intersectsRange(
    AppEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return event.end.isAfter(rangeStart) && event.start.isBefore(rangeEnd);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
