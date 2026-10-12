import 'package:almanac/sessions/session_creation/booking_slot_generator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateBookingSlots', () {
    test('generates weekday slots inside window', () {
      final slots = generateBookingSlots(
        BookingScheduleConfig(
          startDate: DateTime(2026, 7, 6), // Monday
          horizonDays: 1,
          kind: BookingScheduleKind.weekdays,
          weekdays: {DateTime.monday},
          workDays: 1,
          restDays: 1,
          windowStart: const TimeOfDay(hour: 10, minute: 0),
          windowEnd: const TimeOfDay(hour: 12, minute: 0),
          intervalMinutes: 60,
        ),
      );

      expect(slots, hasLength(2));
      expect(slots.first.start, DateTime(2026, 7, 6, 10));
      expect(slots.first.end, DateTime(2026, 7, 6, 11));
      expect(slots.last.start, DateTime(2026, 7, 6, 11));
      expect(slots.last.end, DateTime(2026, 7, 6, 12));
    });

    test('skips inactive weekdays', () {
      final slots = generateBookingSlots(
        BookingScheduleConfig(
          startDate: DateTime(2026, 7, 6),
          horizonDays: 2,
          kind: BookingScheduleKind.weekdays,
          weekdays: {DateTime.monday},
          workDays: 1,
          restDays: 1,
          windowStart: const TimeOfDay(hour: 9, minute: 0),
          windowEnd: const TimeOfDay(hour: 10, minute: 0),
          intervalMinutes: 60,
        ),
      );
      expect(slots, hasLength(1));
      expect(slots.single.start.weekday, DateTime.monday);
    });

    test('cycle mode uses work/rest pattern', () {
      final slots = generateBookingSlots(
        BookingScheduleConfig(
          startDate: DateTime(2026, 7, 1),
          horizonDays: 4,
          kind: BookingScheduleKind.cycle,
          weekdays: const {},
          workDays: 2,
          restDays: 1,
          windowStart: const TimeOfDay(hour: 8, minute: 0),
          windowEnd: const TimeOfDay(hour: 9, minute: 0),
          intervalMinutes: 60,
        ),
      );
      // Days 0,1 work; day 2 rest; day 3 work → 3 slots.
      expect(slots, hasLength(3));
    });

    test('dates mode uses only selected days', () {
      final slots = generateBookingSlots(
        BookingScheduleConfig(
          startDate: DateTime(2026, 7, 1),
          horizonDays: 30,
          kind: BookingScheduleKind.dates,
          weekdays: const {},
          workDays: 1,
          restDays: 1,
          windowStart: const TimeOfDay(hour: 10, minute: 0),
          windowEnd: const TimeOfDay(hour: 11, minute: 0),
          intervalMinutes: 60,
          dates: {DateTime(2026, 7, 8), DateTime(2026, 7, 10)},
        ),
      );
      expect(slots, hasLength(2));
      expect(slots.first.start, DateTime(2026, 7, 8, 10));
      expect(slots.last.start, DateTime(2026, 7, 10, 10));
    });

    test('returns empty for non-positive interval', () {
      final slots = generateBookingSlots(
        BookingScheduleConfig(
          startDate: DateTime(2026, 7, 1),
          horizonDays: 3,
          kind: BookingScheduleKind.weekdays,
          weekdays: {DateTime.wednesday},
          workDays: 1,
          restDays: 1,
          windowStart: const TimeOfDay(hour: 10, minute: 0),
          windowEnd: const TimeOfDay(hour: 12, minute: 0),
          intervalMinutes: 0,
        ),
      );
      expect(slots, isEmpty);
    });
  });
}
