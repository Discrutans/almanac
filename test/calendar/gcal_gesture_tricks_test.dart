import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/event_preview_sheet.dart';
import 'package:almanac/calendar/widgets/forms/create_event_dialog.dart';
import 'package:almanac/calendar/widgets/forms/event_quick_templates_bar.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_grid.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:almanac/calendar/widgets/week/week_day_column.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

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
      theme: buildAlmanacTheme(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      home: home,
    ),
  );
}

AppEvent _sourceEvent() {
  return AppEvent(
    id: 'src-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 18, 12, 33),
      end: DateTime(2026, 9, 18, 13, 33),
    ),
    title: 'Исходная встреча',
    startTime: '12:33',
    endTime: '13:33',
    color: Colors.indigo,
    notes: 'Те же поля',
    kind: CalendarEntryKind.event,
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exact minutes label keeps non-hour start (12:33)', () {
    expect(formatWeekMinutesLabel(12 * 60 + 33), '12:33');
  });

  test('pin keep-visible uses event minutes, not midnight', () {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final pin = 10 * 60;
    final viewportY = 80.0;
    final offset = weekAxisKeepVisibleOffset(
      newAxis: axis,
      pinMinutes: pin,
      viewportY: viewportY,
      maxScrollExtent: 2000,
    );
    expect(offset, axis.yForMinutes(pin) - viewportY);
    expect(weekAxisFallbackPinMinutes(axis, 0), isNot(0));
  });

  test('pinch hourHeight clamp range changes axis total height', () {
    const visible = {8, 9, 10};
    final short = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 36,
    );
    final tall = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 96,
    );
    final shortVisible = buildHourSegments(visible, hourHeight: 36);
    final tallVisible = buildHourSegments(visible, hourHeight: 96);
    expect(short.hourHeight, 36);
    expect(tall.hourHeight, 96);
    expect(tall.totalHeight, greaterThan(short.totalHeight));
    expect(
      tallVisible.fold<double>(0, (s, seg) => s + seg.height),
      greaterThan(shortVisible.fold<double>(0, (s, seg) => s + seg.height)),
    );
    expect((60.0 * 0.5).clamp(36.0, 96.0), 36.0);
    expect((60.0 * 2.0).clamp(36.0, 96.0), 96.0);
  });

  testWidgets('armed live minutes paint exact gutter time 12:33', (
    tester,
  ) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: kWeekHourLabelWidth,
          height: axis.totalHeight,
          child: WeekHourLabels(axis: axis, liveMinutes: 12 * 60 + 33),
        ),
      ),
    );
    expect(find.text('12:33'), findsOneWidget);
  });

  testWidgets('slot resize can grow more than 15 minutes in one gesture', (
    tester,
  ) async {
    WeekGridSlot? slot = WeekGridSlot.fromTap(
      DateTime(2026, 9, 8),
      const TimeOfDay(hour: 10, minute: 0),
    );
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    await tester.binding.setSurfaceSize(Size(240, axis.totalHeight + 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: axis.totalHeight,
            child: StatefulBuilder(
              builder: (context, setState) {
                return WeekTimedDayCanvas(
                  date: DateTime(2026, 9, 8),
                  axis: axis,
                  events: const [],
                  activeProfileId: 'default',
                  profileSeedColors: const {},
                  profileNamesById: const {},
                  onEditEvent: (_) {},
                  selectedSlot: slot,
                  onSelectedSlotChanged: (value) {
                    setState(() => slot = value);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    final handle = tester.getCenter(find.byKey(WeekSelectionFrame.endHandleKey));
    final gesture = await tester.startGesture(handle);
    await tester.pump();
    await gesture.moveBy(Offset(0, kWeekHourHeight + 4));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(slot!.startMinutes, 10 * 60);
    expect(slot!.endMinutes, greaterThanOrEqualTo(11 * 60 + 15));
  });

  testWidgets('preview duplicate opens create form with prefilled fields', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AppEvent? duplicated;

    await tester.pumpWidget(
      _app(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  EventPreviewSheet.show(
                    context: context,
                    event: _sourceEvent(),
                    activeProfileId: 'default',
                    onDuplicate: (event) async {
                      duplicated = event;
                      await CreateEventDialog.show(
                        context: context,
                        date: DateTime(2026, 9, 18),
                        existingEvents: const [],
                        duplicateFrom: event,
                        onPersist: (_) async {},
                      );
                    },
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Дублировать'), findsOneWidget);

    await tester.tap(find.byTooltip('Дублировать'));
    await tester.pumpAndSettle();

    expect(duplicated?.id, 'src-1');
    expect(find.byType(CreateEventDialog), findsOneWidget);
    expect(find.byType(EventQuickTemplatesBar), findsNothing);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(
      fields.any((field) => field.controller?.text == 'Исходная встреча'),
      isTrue,
    );
    expect(fields.any((field) => field.controller?.text == '12:33'), isTrue);
    expect(fields.any((field) => field.controller?.text == '13:33'), isTrue);
    expect(fields.any((field) => field.controller?.text == 'Те же поля'), isTrue);
  });

  testWidgets('create dialog has no quick templates bar', (tester) async {
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
    expect(find.byType(EventQuickTemplatesBar), findsNothing);
  });
}
