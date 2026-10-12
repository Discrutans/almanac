import 'package:almanac/calendar/calendar_month_grid.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/events/event_repository.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/data/profiles/context_profile_repository.dart';
import 'package:almanac/data/profiles/profile_scoped_repositories.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:almanac/state/calendar_events_notifier.dart';
import 'package:almanac/state/calendar_navigation_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads events for visible navigation range', () async {
    final store = await LocalDataStore.openInMemory();
    final eventRepo = InMemoryEventRepository();
    const profileId = 'default';
    eventRepo.ensureProfile(profileId);
    eventRepo.addEvent(
      profileId: profileId,
      event: AppEvent(
        id: 'e1',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ),
        title: 'Test',
        startTime: '09:00',
        endTime: '10:00',
        color: Colors.blue,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        localDataStoreProvider.overrideWithValue(store),
        eventRepositoryProvider.overrideWithValue(eventRepo),
        combinedEventRepositoryProvider.overrideWithValue(
          CombinedEventRepository(eventRepo, {profileId}),
        ),
        visibleProfileIdsProvider.overrideWithValue({profileId}),
        activeProfileIdProvider.overrideWithValue(profileId),
        calendarNavigationProvider.overrideWith(
          () => _FixedNavigationNotifier(
            CalendarNavigationState(
              mode: CalendarMode.month,
              focusedMonth: DateTime(2026, 6, 1),
              selectedDate: DateTime(2026, 6, 10),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(calendarEventsProvider);
    expect(state.hasError, isFalse);
    expect(state.events.any((event) => event.title == 'Test'), isTrue);
  });

  test('reload picks up events added after initial load', () async {
    final store = await LocalDataStore.openInMemory();
    final eventRepo = InMemoryEventRepository();
    const profileId = 'work';
    eventRepo.ensureProfile(profileId);

    final container = ProviderContainer(
      overrides: [
        localDataStoreProvider.overrideWithValue(store),
        eventRepositoryProvider.overrideWithValue(eventRepo),
        combinedEventRepositoryProvider.overrideWithValue(
          CombinedEventRepository(eventRepo, {profileId}),
        ),
        visibleProfileIdsProvider.overrideWithValue({profileId}),
        activeProfileIdProvider.overrideWithValue(profileId),
        calendarNavigationProvider.overrideWith(
          () => _FixedNavigationNotifier(
            CalendarNavigationState(
              mode: CalendarMode.month,
              focusedMonth: DateTime(2026, 6, 1),
              selectedDate: DateTime(2026, 6, 10),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(calendarEventsProvider)
          .events
          .any((event) => event.title == 'Created later'),
      isFalse,
    );

    eventRepo.addEvent(
      profileId: profileId,
      event: AppEvent(
        id: 'new-event',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 10, 14),
          end: DateTime(2026, 6, 10, 15),
        ),
        title: 'Created later',
        startTime: '14:00',
        endTime: '15:00',
        color: Colors.green,
      ),
    );

    container.read(calendarEventsProvider.notifier).reload();

    final state = container.read(calendarEventsProvider);
    expect(state.hasError, isFalse);
    expect(state.events.any((event) => event.title == 'Created later'), isTrue);
  });

  test('month visible range covers full grid including six-week months', () {
    final august2026 = DateTime(2026, 8, 1);
    final gridDates = monthGridDates(august2026);
    expect(gridDates.length, 42);

    final nav = CalendarNavigationState(
      mode: CalendarMode.month,
      focusedMonth: august2026,
      selectedDate: DateTime(2026, 8, 15),
    );
    final range = nav.visibleRange();
    final lastGridDay = gridDates.last;

    expect(lastGridDay.isBefore(range.end), isTrue);
    expect(lastGridDay.isBefore(range.start), isFalse);
  });

  test('reload includes active profile after ensureActiveVisible', () async {
    final store = await LocalDataStore.openInMemory();
    final eventRepo = InMemoryEventRepository();
    final profileRepo =
        store.profileRepository as InMemoryContextProfileRepository;

    profileRepo.createProfile(name: 'Work');
    profileRepo.setActive('default');
    profileRepo.toggleProfileVisibility('default');

    eventRepo.ensureProfile('default');
    eventRepo.ensureProfile(profileRepo.getAll().last.id);

    final container = ProviderContainer(
      overrides: [
        localDataStoreProvider.overrideWithValue(store),
        eventRepositoryProvider.overrideWithValue(eventRepo),
      ],
    );
    addTearDown(container.dispose);

    container.read(contextProfilesProvider.notifier).ensureActiveVisible();

    eventRepo.addEvent(
      profileId: 'default',
      event: AppEvent(
        id: 'visible-after-create',
        dateTimeRange: DateTimeRange(
          start: DateTime(2026, 6, 10, 9),
          end: DateTime(2026, 6, 10, 10),
        ),
        title: 'Now visible',
        startTime: '09:00',
        endTime: '10:00',
        color: Colors.blue,
      ),
    );

    container
        .read(calendarNavigationProvider.notifier)
        .state = CalendarNavigationState(
      mode: CalendarMode.month,
      focusedMonth: DateTime(2026, 6, 1),
      selectedDate: DateTime(2026, 6, 10),
    );
    container.read(calendarEventsProvider.notifier).reload();

    final state = container.read(calendarEventsProvider);
    expect(state.hasError, isFalse);
    expect(state.events.any((event) => event.title == 'Now visible'), isTrue);
  });
}

class _FixedNavigationNotifier extends CalendarNavigationNotifier {
  _FixedNavigationNotifier(this.initial);

  final CalendarNavigationState initial;

  @override
  CalendarNavigationState build() => initial;
}
