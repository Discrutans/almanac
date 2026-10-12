import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/finance/pay_types.dart';

void main() {
  group('reminder fire time', () {
    test('converts minutes before to fire time on same day', () {
      const eventStart = TimeOfDay(hour: 15, minute: 0);

      final fire = reminderFireTimeFromMinutesBefore(
        eventStart: eventStart,
        minutesBefore: 30,
      );

      expect(fire, const TimeOfDay(hour: 14, minute: 30));
    });

    test('converts fire time to minutes before on same day', () {
      const eventStart = TimeOfDay(hour: 15, minute: 0);
      const reminderTime = TimeOfDay(hour: 14, minute: 30);

      final minutes = minutesBeforeFromReminderFireTime(
        eventStart: eventStart,
        reminderTime: reminderTime,
      );

      expect(minutes, 30);
    });

    test('supports previous-day reminder time', () {
      const eventStart = TimeOfDay(hour: 9, minute: 0);
      const reminderTime = TimeOfDay(hour: 21, minute: 0);

      final minutes = minutesBeforeFromReminderFireTime(
        eventStart: eventStart,
        reminderTime: reminderTime,
      );

      expect(minutes, 12 * 60);
    });

    test('roundtrips through text helpers', () {
      final minutes = minutesBeforeFromReminderFireTimeText(
        eventStartTime: '15:00',
        reminderTimeText: '14:30',
      );
      expect(minutes, 30);

      final fireText = reminderFireTimeText(
        eventStartTime: '15:00',
        minutesBefore: 30,
      );
      expect(fireText, '14:30');
    });

    test('rejects values beyond horizon', () {
      final minutes = minutesBeforeFromReminderFireTimeText(
        eventStartTime: '12:00',
        reminderTimeText: '11:00',
      );
      expect(minutes, 60);
      expect(minutes! <= ReminderPresets.maxMinutesBefore, isTrue);
    });
  });
}
