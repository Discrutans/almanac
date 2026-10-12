import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/guest_calendar_projection.dart';
import 'package:almanac/calendar/ics_import.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/month_statistics.dart';
import 'package:almanac/data/events/event_quick_template.dart';
import 'package:almanac/data/guest/guest_calendar_subscription.dart';
import 'package:almanac/data/remote/remote_sync_service.dart';
import 'package:almanac/data/schedules/cyclic_schedule_generator.dart';
import 'package:almanac/finance/savings_goal_calendar_projection.dart';
import 'package:almanac/finance/savings_goal_types.dart';

void main() {
  group('IcsCalendarImport', () {
    test('parses minimal VEVENT block', () {
      const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
UID:test-1
SUMMARY:Guest meetup
DTSTART:20260610T100000Z
DTEND:20260610T110000Z
END:VEVENT
END:VCALENDAR
''';

      final events = IcsCalendarImport.parse(
        ics,
        fallbackColor: const Color(0xFF0000FF),
      );

      expect(events, hasLength(1));
      expect(events.first.title, 'Guest meetup');
      expect(events.first.entrySource, CalendarEntrySource.personal);
    });
  });

  group('GuestCalendarProjection', () {
    test('projects cached guest events in range', () {
      final subscription = GuestCalendarSubscription(
        id: 'sub-1',
        profileId: 'default',
        title: 'Holidays',
        url: 'https://example.com/holidays.ics',
        subscribedAt: DateTime(2026, 1, 1),
        cachedEvents: [
          AppEvent(
            id: 'guest-1',
            dateTimeRange: DateTimeRange(
              start: DateTime(2026, 6, 10, 10),
              end: DateTime(2026, 6, 10, 11),
            ),
            title: 'Guest',
            startTime: '10:00',
            endTime: '11:00',
            color: Colors.grey,
          ),
        ],
      );

      final events = GuestCalendarProjection.expandForProfiles(
        profileIds: const ['default'],
        subscriptions: [subscription],
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 30),
      );

      expect(events, hasLength(1));
      expect(events.first.entrySource, CalendarEntrySource.guestCalendar);
    });
  });

  group('EventQuickTemplate', () {
    test('roundtrips through json', () {
      const template = EventQuickTemplate(
        id: 'tpl-1',
        title: 'Standup',
        durationMinutes: 15,
        colorValue: 0xFF00FF00,
      );

      final restored = EventQuickTemplate.fromJson(template.toJson());
      expect(restored.title, 'Standup');
      expect(restored.durationMinutes, 15);
    });
  });

  group('MonthStatistics expansion', () {
    test('counts notes bookings and savings goals', () {
      final stats = computeMonthStatistics(
        focusedMonth: DateTime(2026, 6, 1),
        events: [
          AppEvent(
            id: 'note-1',
            dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 6, 5)),
            title: 'Note',
            startTime: '',
            endTime: '',
            color: Colors.blue,
            kind: CalendarEntryKind.note,
          ).taggedWith(CalendarEntrySource.personal),
          AppEvent(
            id: 'booking-1',
            dateTimeRange: DateTimeRange(
              start: DateTime(2026, 6, 6, 10),
              end: DateTime(2026, 6, 6, 11),
            ),
            title: 'Booking',
            startTime: '10:00',
            endTime: '11:00',
            color: Colors.orange,
          ).taggedWith(CalendarEntrySource.booking),
          SavingsGoalCalendarProjection.toAppEvent(
            SavingsGoal(
              id: 'goal-1',
              profileId: 'default',
              title: 'Trip',
              targetAmount: 100000,
              savedAmount: 25000,
              targetDate: DateTime(2026, 6, 20),
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
        ],
      );

      expect(stats.noteCount, 1);
      expect(stats.bookingCount, 1);
      expect(stats.savingsGoalCount, 1);
    });
  });

  group('SavingsGoal savedAmount', () {
    test('projects saved amount into event endTime', () {
      final event = SavingsGoalCalendarProjection.toAppEvent(
        SavingsGoal(
          id: 'goal-1',
          profileId: 'default',
          title: 'Laptop',
          targetAmount: 100000,
          savedAmount: 40000,
          targetDate: DateTime(2026, 12, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      expect(event.savingsSavedAmount, 40000);
      expect(event.savingsProgressRatio, closeTo(0.4, 0.001));
    });
  });

  group('Shift holiday warning helper', () {
    test('counts work days that fall on fixed holidays', () {
      final count = countShiftDaysOnHolidays(
        cycleStartDate: DateTime(2026, 1, 1),
        workDays: 2,
        restDays: 2,
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 31),
      );

      expect(count, greaterThan(0));
    });
  });

  group('RemoteSyncResult conflict flags', () {
    test('supports conflict metadata', () {
      const result = RemoteSyncResult(
        success: true,
        message: 'conflict',
        conflictWithLocal: true,
      );

      expect(result.conflictWithLocal, isTrue);
      expect(result.restoredFromRemote, isFalse);
    });
  });
}
