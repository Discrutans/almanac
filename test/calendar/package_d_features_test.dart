import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/booking/pending_booking_calendar_projection.dart';
import 'package:almanac/booking/booking_types.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/ical_export.dart';

void main() {
  group('PendingBookingCalendarProjection', () {
    test('projects local pending request into visible range', () {
      final events = PendingBookingCalendarProjection.expandForProfiles(
        localPending: [
          BookingRequest(
            id: 'req-1',
            profileId: 'default',
            templateId: 'tpl-1',
            templateToken: 'demo',
            start: DateTime(2026, 6, 10, 10),
            end: DateTime(2026, 6, 10, 11),
            createdAt: DateTime(2026, 6, 1),
            status: BookingRequestStatus.pending,
          ),
        ],
        remotePending: const [],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 30),
      );

      expect(events, hasLength(1));
      expect(events.first.entrySource, CalendarEntrySource.bookingPending);
    });
  });

  group('IcsCalendarExport', () {
    test('exports timed event with summary and uid', () {
      final ics = IcsCalendarExport.exportEvents([
        AppEvent(
          id: 'evt-1',
          dateTimeRange: DateTimeRange(
            start: DateTime(2026, 6, 10, 10),
            end: DateTime(2026, 6, 10, 11),
          ),
          title: 'Meeting',
          startTime: '10:00',
          endTime: '11:00',
          color: const Color(0xFF0000FF),
        ),
      ]);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('SUMMARY:Meeting'));
      expect(ics, contains('UID:evt-1@almanac'));
    });
  });
}
