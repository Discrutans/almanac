import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import '../calendar/calendar_types.dart';
import '../core/theme/almanac_tokens.dart';
import '../platform/session_types.dart';

/// Свободные и занятые слоты сессии записи на календарь участника.
final class BookingSlotCalendarProjection {
  BookingSlotCalendarProjection._();

  static List<AppEvent> expand({
    required Iterable<PlatformSession> sessions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    String? profileId,
  }) {
    final events = <AppEvent>[];
    for (final session in sessions) {
      if (session.mode != SessionMode.booking || !session.isOpen) continue;
      for (final slot in session.state.slots) {
        final event = _fromSlot(session, slot, profileId: profileId);
        if (_intersectsRange(event, rangeStart, rangeEnd)) {
          events.add(event);
        }
      }
    }
    return events;
  }

  static AppEvent _fromSlot(
    PlatformSession session,
    SessionSlot slot, {
    String? profileId,
  }) {
    final start = slot.start.toLocal();
    final end = slot.end.toLocal();
    final full = session.isSlotFull(slot.id);
    final title = slot.label?.trim().isNotEmpty == true
        ? slot.label!.trim()
        : session.title;

    return AppEvent(
      id: AppEvent.bookingSlotEventId(session.token, slot.id),
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: title,
      startTime:
          '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
      endTime:
          '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
      color: full ? AlmanacBrand.bookingFull : AlmanacBrand.bookingOpen,
      checklist: const [],
      interaction: EventInteraction.allowNone(),
      contextProfileId: profileId ?? session.profileId,
      notes: session.title,
    ).taggedWith(CalendarEntrySource.bookingSlot);
  }

  static bool _intersectsRange(
    AppEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return event.end.isAfter(rangeStart) && event.start.isBefore(rangeEnd);
  }
}
