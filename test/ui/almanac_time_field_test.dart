import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/core/ui/almanac_time_field.dart';

void main() {
  group('parseAlmanacTime', () {
    test('parses HH:mm', () {
      expect(parseAlmanacTime('09:30'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseAlmanacTime('23:59'), const TimeOfDay(hour: 23, minute: 59));
    });

    test('parses digit-only shorthand', () {
      expect(parseAlmanacTime('930'), const TimeOfDay(hour: 9, minute: 30));
      expect(parseAlmanacTime('1230'), const TimeOfDay(hour: 12, minute: 30));
    });

    test('returns null for invalid input', () {
      expect(parseAlmanacTime(''), isNull);
      expect(parseAlmanacTime('12'), isNull);
      expect(parseAlmanacTime('25:00'), isNull);
    });
  });

  group('AlmanacTimeInputFormatter', () {
    test('inserts colon after hours', () {
      final formatter = AlmanacTimeInputFormatter();
      expect(
        formatter
            .formatEditUpdate(
              const TextEditingValue(text: ''),
              const TextEditingValue(text: '0930'),
            )
            .text,
        '09:30',
      );
    });
  });

  group('formatAlmanacTime', () {
    test('pads values', () {
      expect(formatAlmanacTime(const TimeOfDay(hour: 9, minute: 5)), '09:05');
    });
  });
}
