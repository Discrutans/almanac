import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/booking/booking_slot_calendar_projection.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/platform/session_types.dart';

void main() {
  test('projects open booking slots onto the calendar', () {
    final start = DateTime(2026, 9, 12, 12);
    final session = PlatformSession(
      id: 's1',
      token: 'tokentoken12abcd',
      profileId: 'profile-1',
      mode: SessionMode.booking,
      title: 'Стрижка',
      state: SessionState(
        slots: [
          SessionSlot(
            id: 'slot-1',
            start: start,
            end: start.add(const Duration(hours: 1)),
          ),
        ],
      ),
      version: 1,
      status: SessionStatus.open,
      createdAt: start,
    );

    final events = BookingSlotCalendarProjection.expand(
      sessions: [session],
      rangeStart: DateTime(2026, 9, 1),
      rangeEnd: DateTime(2026, 9, 30),
      profileId: 'profile-1',
    );

    expect(events, hasLength(1));
    expect(events.first.entrySource, CalendarEntrySource.bookingSlot);
    expect(AppEvent.parseBookingSlotEventId(events.first.id), (
      token: 'tokentoken12abcd',
      slotId: 'slot-1',
    ));
  });
}
