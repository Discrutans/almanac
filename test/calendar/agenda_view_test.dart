import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/views/agenda_view.dart';
import 'package:almanac/calendar/widgets/event_list_item.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event({required int day, required int index}) {
  final start = DateTime(2026, 6, day, 9 + (index % 8));
  return AppEvent(
    id: 'e-$day-$index',
    dateTimeRange: DateTimeRange(
      start: start,
      end: start.add(const Duration(hours: 1)),
    ),
    title: 'Event $day-$index',
    startTime: '09:00',
    endTime: '10:00',
    color: Colors.blue,
    checklist: const [],
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  testWidgets(
    'agenda lazily builds event tiles so snap can animate with large datasets',
    (tester) async {
      const viewport = Size(360, 700);
      final events = [
        for (var day = 1; day <= 28; day++)
          for (var index = 0; index < 8; index++)
            _event(day: day, index: index),
      ];
      expect(events.length, 224);

      final store = await LocalDataStore.openInMemory(seedDemoData: false);

      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [localDataStoreProvider.overrideWithValue(store)],
          child: MaterialApp(
            locale: const Locale('ru'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildAlmanacTheme(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            home: MediaQuery(
              data: const MediaQueryData(size: viewport),
              child: Scaffold(
                body: SizedBox(
                  width: viewport.width,
                  height: viewport.height,
                  child: AgendaCalendarView(
                    focusedMonth: DateTime(2026, 6, 1),
                    selectedDate: DateTime(2026, 6, 1),
                    events: events,
                    activeProfileId: 'default',
                    onDateSelected: (_) {},
                    onEditEvent: (_) {},
                    onDeleteEvent: (_) async => true,
                    onCreateEvent: () {},
                    onEventUpdated: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final builtTiles = find.byType(EventListItem).evaluate().length;
      expect(builtTiles, greaterThan(0));
      expect(builtTiles, lessThan(events.length));
      expect(builtTiles, lessThan(80));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -280));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(EventListItem), findsWidgets);
    },
  );

  testWidgets('agenda card tap opens preview; card has no persistent edit pill', (
    tester,
  ) async {
    const viewport = Size(360, 700);
    AppEvent? viewed;
    AppEvent? edited;
    final events = [_event(day: 1, index: 0)];
    final store = await LocalDataStore.openInMemory(seedDemoData: false);

    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAlmanacTheme(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          home: MediaQuery(
            data: const MediaQueryData(size: viewport),
            child: Scaffold(
              body: SizedBox(
                width: viewport.width,
                height: viewport.height,
                child: AgendaCalendarView(
                  focusedMonth: DateTime(2026, 6, 1),
                  selectedDate: DateTime(2026, 6, 1),
                  events: events,
                  activeProfileId: 'default',
                  onDateSelected: (_) {},
                  onViewEvent: (event) => viewed = event,
                  onEditEvent: (event) => edited = event,
                  onDeleteEvent: (_) async => true,
                  onCreateEvent: () {},
                  onEventUpdated: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Event 1-0'));
    await tester.pumpAndSettle();
    expect(viewed?.id, 'e-1-0');
    expect(edited, isNull);
    expect(find.text('Изменить'), findsNothing);
    expect(find.textContaining('Смахните'), findsNothing);
  });
}
