import 'package:almanac/calendar/widgets/agenda_day_snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day1 = DateTime(2026, 7, 19);

  final day2 = DateTime(2026, 7, 20);

  final today = DateTime(2026, 7, 21);

  final days = [day1, day2, today];

  double? headerTopFor(DateTime day) {
    return switch (day) {
      _ when day == day1 => -120,
      _ when day == day2 => -40,
      _ when day == today => 48,
      _ => null,
    };
  }

  test('snaps when today header enters top edge band', () {
    expect(
      resolveAgendaDaySnapTargetFromHeaderTops(
        days: days,
        headerTopFor: headerTopFor,
        topmostDay: day2,
      ),
      today,
    );
  });

  test('snaps topmost day within extended band below edge', () {
    expect(
      resolveAgendaDaySnapTargetFromHeaderTops(
        days: days,
        headerTopFor: (day) {
          return switch (day) {
            _ when day == day1 => -300,
            _ when day == day2 => 140,
            _ when day == today => 320,
            _ => null,
          };
        },
        topmostDay: day2,
      ),
      day2,
    );
  });

  test('does not snap when header is far below extended band', () {
    expect(
      resolveAgendaDaySnapTargetFromHeaderTops(
        days: days,
        headerTopFor: (day) {
          return switch (day) {
            _ when day == day1 => -300,
            _ when day == day2 => -80,
            _ when day == today => 220,
            _ => null,
          };
        },
        topmostDay: day2,
      ),
      isNull,
    );
  });

  test('does not snap when reading events below aligned header', () {
    expect(
      resolveAgendaDaySnapTargetFromHeaderTops(
        days: [today],
        headerTopFor: (_) => -64,
        topmostDay: today,
      ),
      isNull,
    );
  });

  test('does not snap when header already aligned', () {
    expect(
      resolveAgendaDaySnapTargetFromHeaderTops(
        days: [today],
        headerTopFor: (_) => 0,
        topmostDay: today,
      ),
      isNull,
    );
  });

  test('resolveAgendaTodayScrollTarget prefers today when it has events', () {
    expect(
      resolveAgendaTodayScrollTarget(daysWithEvents: days, today: today),
      today,
    );
  });

  test('resolveAgendaTodayScrollTarget falls back to next day with events', () {
    expect(
      resolveAgendaTodayScrollTarget(
        daysWithEvents: [day1, day2],
        today: today,
      ),
      day2,
    );
  });

  test(
    'resolveAgendaTodayScrollTarget falls back to last day before today',
    () {
      expect(
        resolveAgendaTodayScrollTarget(
          daysWithEvents: [day1, day2],
          today: DateTime(2026, 7, 22),
        ),
        day2,
      );
    },
  );

  test(
    'estimateAgendaDayScrollOffset sums collapsed and expanded sections',
    () {
      final offset = estimateAgendaDayScrollOffset(
        days: days,
        target: today,
        isCollapsed: (day) => day == day1,
        eventCount: (day) => day == day2 ? 2 : 0,
        headerBlockHeight: 40,
        collapsedBlockHeight: 30,
        eventTileHeight: 50,
        firstSectionTopInset: 8,
        sectionTopInset: 12,
        sectionBottomInset: 10,
        headerToEventsGap: 4,
        eventGap: 6,
      );

      // day1 collapsed: 8 + 30 + 10 = 48
      // day2 expanded with 2 events: 12 + 40 + 4 + 100 + 6 + 10 = 172
      expect(offset, 220);
    },
  );

  test('estimateAgendaDayScrollOffset returns zero for first day', () {
    expect(
      estimateAgendaDayScrollOffset(
        days: days,
        target: day1,
        isCollapsed: (_) => false,
        eventCount: (_) => 1,
      ),
      0,
    );
  });

  test('agendaDayAttractDuration scales with travel distance', () {
    final shortSnap = agendaDayAttractDuration(distance: 48);
    final longSnap = agendaDayAttractDuration(distance: 180);
    expect(shortSnap.inMilliseconds, greaterThanOrEqualTo(260));
    expect(longSnap.inMilliseconds, greaterThan(shortSnap.inMilliseconds));
    expect(longSnap.inMilliseconds, lessThanOrEqualTo(520));
  });
}
