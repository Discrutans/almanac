import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/day_events_sheet.dart';
import 'package:almanac/calendar/widgets/chrome/event_preview_sheet.dart';
import 'package:almanac/calendar/widgets/forms/create_event_dialog.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

import '../helpers/almanac_layout_harness.dart';

const _viewport = Size(390, 844);
const _statusBar = 24.0;
const _navBar = 48.0;

AppEvent _timedEvent() {
  return AppEvent(
    id: 'preview-bar',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 10, 10),
      end: DateTime(2026, 9, 10, 11),
    ),
    title: 'Встреча',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.indigo,
    kind: CalendarEntryKind.event,
    interaction: EventInteraction.allowNone(),
  );
}

Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required Widget home,
  required LocalDataStore store,
}) async {
  final bar = logicalViewPadding(tester, top: _statusBar, bottom: _navBar);
  tester.view.padding = bar;
  tester.view.viewPadding = bar;
  tester.view.physicalSize = Size(
    _viewport.width * tester.view.devicePixelRatio,
    _viewport.height * tester.view.devicePixelRatio,
  );
  await tester.binding.setSurfaceSize(_viewport);
  addTearDown(() {
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.view.resetPhysicalSize();
    tester.binding.setSurfaceSize(null);
  });

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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create event save button stays above the android bar', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();

    await _pumpSheetHost(
      tester,
      store: store,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                CreateEventDialog.show(
                  context: context,
                  date: DateTime(2026, 9, 10),
                  existingEvents: const [],
                  onPersist: (_) async {},
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final save = find.text('Сохранить');
    expect(save, findsOneWidget);
    expect(
      tester.getRect(save).bottom,
      lessThanOrEqualTo(_viewport.height - _navBar + 0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview title sits below the status bar', (tester) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();

    await _pumpSheetHost(
      tester,
      store: store,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                EventPreviewSheet.show(
                  context: context,
                  event: _timedEvent(),
                  activeProfileId: 'default',
                  onSave:
                      (
                        _, {
                        recurrenceScope = RecurrenceEditScope.wholeSeries,
                      }) async {},
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = find.text('Событие');
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(_statusBar));
    expect(tester.getTopLeft(title).dy, lessThan(_statusBar + 80));
    expect(
      tester.getRect(find.text('Изменить')).bottom,
      lessThan(_viewport.height - _navBar),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('day events footer stays above the android bar', (tester) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();

    await _pumpSheetHost(
      tester,
      store: store,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                DayEventsSheet.show(
                  context: context,
                  date: DateTime(2026, 9, 10),
                  activeProfileId: 'default',
                  onEditEvent: (_) {},
                  onDeleteEvent: (_) async => true,
                  onCreateEvent: () {},
                  onEventUpdated: (_) {},
                  onOpenWeekView: () {},
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final add = find.text('Добавить');
    expect(add, findsOneWidget);
    expect(
      tester.getRect(add).bottom,
      lessThanOrEqualTo(_viewport.height - _navBar + 0.5),
    );
    expect(tester.takeException(), isNull);
  });
}
