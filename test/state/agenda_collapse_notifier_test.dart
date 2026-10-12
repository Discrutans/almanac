import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/state/agenda_collapse_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

void main() {
  test('toggleCollapseAll collapses and expands month days', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(agendaCollapseProvider.notifier);
    const monthKey = '2026-7';
    final days = [DateTime(2026, 7, 10), DateTime(2026, 7, 11)];

    expect(notifier.areAllExpanded(monthKey, days), isTrue);

    notifier.toggleCollapseAll(monthKey, days);
    expect(notifier.areAllExpanded(monthKey, days), isFalse);
    expect(notifier.isDayCollapsed(monthKey, days.first), isTrue);

    notifier.toggleCollapseAll(monthKey, days);
    expect(notifier.areAllExpanded(monthKey, days), isTrue);
  });

  test('focusTodayOnly keeps only today expanded', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(agendaCollapseProvider.notifier);
    const monthKey = '2026-7';
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final days = [todayDay.subtract(const Duration(days: 1)), todayDay];

    notifier.focusTodayOnly(monthKey, days);

    expect(notifier.isDayCollapsed(monthKey, days.first), isTrue);
    expect(notifier.isDayCollapsed(monthKey, todayDay), isFalse);
  });

  test('focusDayOnly keeps only selected day expanded', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(agendaCollapseProvider.notifier);
    const monthKey = '2026-7';
    final selected = DateTime(2026, 7, 16);
    final days = [DateTime(2026, 7, 15), selected, DateTime(2026, 7, 17)];

    notifier.focusDayOnly(monthKey, days, selected);

    expect(notifier.isDayCollapsed(monthKey, days.first), isTrue);
    expect(notifier.isDayCollapsed(monthKey, selected), isFalse);
    expect(notifier.isDayCollapsed(monthKey, days.last), isTrue);
  });

  test('agendaDaysWithEventsForMonth filters empty days', () {
    final start = DateTime(2026, 8, 3, 10);
    final endSameDay = DateTime(2026, 8, 3, 14);
    final days = agendaDaysWithEventsForMonth([
      AppEvent(
        id: '1',
        dateTimeRange: DateTimeRange(
          start: start,
          end: start.add(const Duration(hours: 1)),
        ),
        title: 'Meet',
        startTime: '10:00',
        endTime: '11:00',
        color: Colors.blue,
        interaction: EventInteraction.allowNone(),
      ),
      AppEvent(
        id: '2',
        dateTimeRange: DateTimeRange(
          start: endSameDay,
          end: endSameDay.add(const Duration(hours: 1)),
        ),
        title: 'Later',
        startTime: '14:00',
        endTime: '15:00',
        color: Colors.green,
        interaction: EventInteraction.allowNone(),
      ),
    ], DateTime(2026, 8, 1));

    expect(days, [DateTime(2026, 8, 3)]);
    expect(days.length, 1);
  });

  test(
    'agendaVisibleDays includes selected day in focused month without events',
    () {
      final selected = DateTime(2026, 8, 16);
      final days = agendaVisibleDays(
        const [],
        DateTime(2026, 8, 1),
        highlightDay: selected,
        today: DateTime(2026, 7, 1),
      );

      expect(days, [selected]);
    },
  );

  test('agendaVisibleDays includes today in focused month without events', () {
    final today = DateTime(2026, 7, 24);
    final days = agendaVisibleDays(
      const [],
      DateTime(2026, 7, 1),
      today: today,
    );

    expect(days, [today]);
  });

  test(
    'agendaVisibleDays keeps event days sorted when today already listed',
    () {
      final today = DateTime(2026, 7, 24);
      final earlier = DateTime(2026, 7, 10);
      final days = agendaVisibleDays(
        [
          AppEvent(
            id: '1',
            dateTimeRange: DateTimeRange(
              start: DateTime(2026, 7, 10, 9),
              end: DateTime(2026, 7, 10, 10),
            ),
            title: 'Meet',
            startTime: '09:00',
            endTime: '10:00',
            color: Colors.blue,
            interaction: EventInteraction.allowNone(),
          ),
        ],
        DateTime(2026, 7, 1),
        today: today,
      );

      expect(days, [earlier, today]);
    },
  );
}
