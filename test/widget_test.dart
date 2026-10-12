import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:almanac/app/app.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:almanac/state/calendar_navigation_notifier.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    final store = await LocalDataStore.openInMemory();
    store.bindPersistence();

    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: const AlmanacApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('calendar shows localized controls and Monday-first weekdays', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Месяц'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);
    expect(find.text('Список'), findsOneWidget);
    expect(find.text('Год'), findsOneWidget);
    expect(find.text('ПН'), findsOneWidget);
    expect(find.text('ВС'), findsOneWidget);
  });

  testWidgets('selecting a date in month view opens day actions', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory();
    store.bindPersistence();
    store.saveCalendarMode('month');

    late ProviderContainer container;
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [localDataStoreProvider.overrideWithValue(store)],
        ),
        child: const AlmanacApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(calendarNavigationProvider).mode, CalendarMode.month);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();

    expect(container.read(calendarNavigationProvider).mode, CalendarMode.month);
    expect(find.text('События дня'), findsNothing);
    expect(find.text('Открыть неделю'), findsOneWidget);
    expect(find.text('Добавить'), findsWidgets);
  });

  testWidgets('long-pressing a date in month view opens week view', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory();
    store.bindPersistence();
    store.saveCalendarMode('month');

    late ProviderContainer container;
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [localDataStoreProvider.overrideWithValue(store)],
        ),
        child: const AlmanacApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('2').first);
    await tester.pumpAndSettle();

    expect(container.read(calendarNavigationProvider).mode, CalendarMode.week);
  });

  testWidgets(
    'month day tap lists events and card tap opens preview then edit',
    (tester) async {
      final store = await LocalDataStore.openInMemory(seedDemoData: false);
      store.bindPersistence();
      store.saveCalendarMode('month');
      store.markSwipeActionsHintSeen();

      final now = DateTime.now();
      final day = DateTime(now.year, now.month, 2, 11);
      store.eventRepository.addEvent(
        profileId: 'default',
        event: AppEvent(
          id: 'month-day-card',
          dateTimeRange: DateTimeRange(
            start: day,
            end: day.add(const Duration(hours: 1)),
          ),
          title: 'Уникальная встреча месяца',
          startTime: '11:00',
          endTime: '12:00',
          color: Colors.indigo,
        ),
      );

      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localDataStoreProvider.overrideWithValue(store)],
          child: const AlmanacApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();

      expect(find.text('Уникальная встреча месяца'), findsOneWidget);
      expect(find.text('Изменить'), findsNothing);
      expect(find.text('Открыть неделю'), findsOneWidget);
      expect(find.text('Добавить'), findsWidgets);

      await tester.tap(find.text('Уникальная встреча месяца'));
      await tester.pumpAndSettle();

      expect(find.text('Уникальная встреча месяца'), findsWidgets);
      expect(find.text('Сохранить'), findsNothing);
      expect(find.text('Событие'), findsOneWidget);
      expect(find.text('Изменить'), findsOneWidget);

      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();

      expect(find.text('Сохранить'), findsOneWidget);
    },
  );
}
