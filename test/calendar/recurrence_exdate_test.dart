import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_entry_capabilities.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/events/recurrence_exdate.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:flutter/material.dart';

void main() {
  group('RecurrenceExdateCodec', () {
    test('parseStored splits RRULE and EXDATE lines', () {
      const stored =
          'FREQ=DAILY;INTERVAL=1\nEXDATE:20260103T090000\nEXDATE:20260105T090000';

      final parsed = RecurrenceExdateCodec.parseStored(stored);

      expect(parsed.rrule, 'FREQ=DAILY;INTERVAL=1');
      expect(parsed.exdates, hasLength(2));
      expect(parsed.exdates.first, DateTime(2026, 1, 3));
      expect(parsed.exdates.last, DateTime(2026, 1, 5));
    });

    test('encodeStored embeds EXDATE with series start time', () {
      final encoded = RecurrenceExdateCodec.encodeStored(
        rrule: 'FREQ=DAILY;INTERVAL=1',
        exclusionDays: [DateTime(2026, 1, 3), DateTime(2026, 1, 5)],
        seriesStart: DateTime(2026, 1, 1, 9),
      );

      expect(encoded, contains('FREQ=DAILY;INTERVAL=1'));
      expect(encoded, contains('EXDATE:20260103T090000'));
      expect(encoded, contains('EXDATE:20260105T090000'));
    });

    test('mergeExclusionDays deduplicates by calendar day', () {
      final merged = RecurrenceExdateCodec.mergeExclusionDays(
        [DateTime(2026, 1, 3, 9), DateTime(2026, 1, 3, 18)],
        [DateTime(2026, 1, 4)],
      );

      expect(merged, hasLength(2));
      expect(merged.first, DateTime(2026, 1, 3));
      expect(merged.last, DateTime(2026, 1, 4));
    });
  });

  group('RecurrenceEngine EXDATE integration', () {
    test('expandEvent skips days encoded as EXDATE in stored rrule', () {
      final master = AppEvent(
        id: 'series-exdate',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 1, 9),
          end: DateTime(2026, 6, 1, 10),
        ),
        title: 'Daily',
        startTime: '09:00',
        endTime: '10:00',
        color: Colors.blue,
        rrule: 'FREQ=DAILY;INTERVAL=1',
        seriesId: 'series-exdate',
        recurrenceExclusions: [DateTime(2026, 6, 3)],
      );

      final expanded = RecurrenceEngine.expandEvent(
        master,
        rangeStart: DateTime(2026, 6, 1),
        rangeEnd: DateTime(2026, 6, 6),
      );

      expect(expanded.any((event) => event.start.day == 3), isFalse);
      expect(expanded, hasLength(4));
    });
    test('stored rrule roundtrip through parse and encode', () {
      const stored =
          'FREQ=DAILY;INTERVAL=1\nEXDATE:20260603T090000\nEXDATE:20260605T090000';
      final parsed = RecurrenceExdateCodec.parseStored(stored);
      final merged = RecurrenceExdateCodec.mergeExclusionDays(
        parsed.exdates,
        const [],
      );
      final reencoded = RecurrenceExdateCodec.encodeStored(
        rrule: parsed.rrule,
        exclusionDays: merged,
        seriesStart: DateTime(2026, 6, 1, 9),
      );

      expect(reencoded, contains('FREQ=DAILY;INTERVAL=1'));
      expect(reencoded, contains('EXDATE:20260603T090000'));
      expect(reencoded, contains('EXDATE:20260605T090000'));
    });
  });

  group('CalendarEntrySource.booking', () {
    test('legacy session id resolves to booking source', () {
      final event = AppEvent(
        id: AppEvent.bookingEventId('req-1'),
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 1, 10),
          end: DateTime(2026, 6, 1, 11),
        ),
        title: 'Session',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.blue,
      );

      expect(event.entrySource, CalendarEntrySource.booking);
      expect(event.capabilities.canChangeKind, isFalse);
      expect(event.capabilities.canDelete, isTrue);
    });

    test('explicit booking tag is persisted source', () {
      final event = AppEvent(
        id: 'custom-id',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 1, 10),
          end: DateTime(2026, 6, 1, 11),
        ),
        title: 'Session',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.blue,
      ).taggedWith(CalendarEntrySource.booking);

      expect(event.entrySource, CalendarEntrySource.booking);
      expect(event.explicitEntrySource, CalendarEntrySource.booking);
    });
  });
}
