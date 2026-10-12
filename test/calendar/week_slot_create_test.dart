import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/widgets/forms/create_event_dialog.dart';
import 'package:almanac/calendar/widgets/week/week_events_drop_grid.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_grid.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({required Widget home, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildAlmanacTheme(seedColor: Colors.blue, brightness: Brightness.light),
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selected slot exposes start and end for the plus button', () {
    final slot = WeekGridSlot(
      date: DateTime(2026, 9, 18),
      startMinutes: 10 * 60,
      endMinutes: 11 * 60 + 15,
    );
    expect(slot.startTime, const TimeOfDay(hour: 10, minute: 0));
    expect(slot.endTime, const TimeOfDay(hour: 11, minute: 15));
  });

  testWidgets('create form uses selected slot times instead of 08:00–10:30', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreateEventDialog(
              date: DateTime(2026, 9, 18),
              existingEvents: const [],
              onPersist: (_) async {},
              initialStartTime: const TimeOfDay(hour: 10, minute: 0),
              initialEndTime: const TimeOfDay(hour: 11, minute: 15),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.any((field) => field.controller?.text == '10:00'), isTrue);
    expect(fields.any((field) => field.controller?.text == '11:15'), isTrue);
    expect(fields.any((field) => field.controller?.text == '08:00'), isFalse);
  });

  testWidgets('create form offers event, note and checklist chips', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreateEventDialog(
              date: DateTime(2026, 9, 18),
              existingEvents: const [],
              onPersist: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Событие'), findsOneWidget);
    expect(find.text('Заметка'), findsOneWidget);
    expect(find.text('Чек-лист'), findsOneWidget);
  });

  testWidgets('selected slot keeps full hour axis; resize stays expanded', (
    tester,
  ) async {
    final weekStart = DateTime(2026, 9, 14);
    final dates = List<DateTime>.generate(
      7,
      (index) => calendarDayKey(weekStart.add(Duration(days: index))),
    );
    final selected = dates[4];
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 700,
            child: WeekEventsDropGrid(
              weekDates: dates,
              eventsIndex: const {},
              selectedDate: selected,
              activeProfileId: 'default',
              onEditEvent: (_) {},
              selectedSlot: WeekGridSlot.fromTap(
                selected,
                const TimeOfDay(hour: 10, minute: 0),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Week axis always shows a full 24-hour day.
    expect(find.text('08:00'), findsWidgets);
    expect(
      tester
          .widget<WeekHourGridLines>(find.byType(WeekHourGridLines).first)
          .axis
          .segments
          .where((s) => s.isHour)
          .length,
      24,
    );
    final hourHeight = tester
        .widget<WeekHourGridLines>(find.byType(WeekHourGridLines).first)
        .axis
        .hourHeight;
    expect(
      tester.getSize(find.byType(WeekHourGridLines).first).height,
      closeTo(24 * hourHeight, 0.5),
    );

    await tester.ensureVisible(find.byKey(WeekSelectionFrame.endHandleKey));
    await tester.pumpAndSettle();

    final handle = tester.getCenter(find.byKey(WeekSelectionFrame.endHandleKey));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();

    expect(
      tester
          .widget<WeekHourGridLines>(find.byType(WeekHourGridLines).first)
          .axis
          .segments
          .where((s) => s.isHour)
          .length,
      24,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    // Slot still selected → axis remains expanded.
    expect(
      tester
          .widget<WeekHourGridLines>(find.byType(WeekHourGridLines).first)
          .axis
          .segments
          .where((s) => s.isHour)
          .length,
      24,
    );
  });
}
