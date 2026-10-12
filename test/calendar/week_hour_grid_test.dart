import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_day_column.dart';
import 'package:almanac/calendar/widgets/week/week_drag_policy.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_event_tile.dart';
import 'package:almanac/calendar/widgets/week/week_hour_grid.dart';
import 'package:almanac/calendar/widgets/week/week_selection_frame.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/core/theme/almanac_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatWeekHourLabel uses zero-padded HH:00', () {
    expect(formatWeekHourLabel(0), '00:00');
    expect(formatWeekHourLabel(24), isEmpty);
    expect(formatWeekHourLabel(1), '01:00');
    expect(formatWeekHourLabel(8), '08:00');
    expect(formatWeekHourLabel(13), '13:00');
  });

  test('weekHourLabelFontSize scales with hour height', () {
    expect(weekHourLabelFontSize(kWeekHourHeight), closeTo(10, 0.01));
    expect(
      weekHourLabelFontSize(kWeekHourHeightMin),
      lessThan(weekHourLabelFontSize(kWeekHourHeight)),
    );
    expect(
      weekHourLabelFontSize(kWeekHourHeightMax),
      greaterThan(weekHourLabelFontSize(kWeekHourHeight)),
    );
  });

  test('weekHourLabelSlotWidth fits HH:00 without shrinking below base', () {
    expect(weekHourLabelSlotWidth(kWeekHourHeight), greaterThanOrEqualTo(54));
    expect(
      weekHourLabelSlotWidth(kWeekHourHeightMax),
      greaterThan(weekHourLabelSlotWidth(kWeekHourHeight)),
    );
  });

  test('formatWeekMinutesLabel pads hours and minutes', () {
    expect(formatWeekMinutesLabel(0), '00:00');
    expect(formatWeekMinutesLabel(10 * 60 + 45), '10:45');
    expect(formatWeekMinutesLabel(24 * 60), '24:00');
  });

  test('expanded axis has a half-hour line in the middle of every hour', () {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final hours = weekHourGridHourYs(axis);
    final halves = weekHourGridHalfHourYs(axis);
    expect(hours, hasLength(25));
    expect(halves, hasLength(24));
    for (var hour = 0; hour < 24; hour++) {
      expect(hours[hour], hour * kWeekHourHeight);
      expect(halves[hour], hour * kWeekHourHeight + kWeekHourHeight / 2);
    }
    expect(hours.last, 24 * kWeekHourHeight);
  });

  test('WeekGridSlot.fromTap uses one hour duration and hour-cell floor', () {
    final slot = WeekGridSlot.fromTap(
      DateTime(2026, 9, 18),
      const TimeOfDay(hour: 9, minute: 17),
    );
    expect(slot.startMinutes, 9 * 60);
    expect(slot.endMinutes, 10 * 60);
    expect(slot.startTime, const TimeOfDay(hour: 9, minute: 0));
  });

  testWidgets('now line is only painted on today', (tester) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: 80,
          child: WeekNowLine(axis: axis, date: DateTime(2020, 1, 1)),
        ),
      ),
    );
    expect(find.byKey(WeekNowLine.lineKey), findsNothing);
    expect(find.byKey(WeekNowLine.dotKey), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: axis.totalHeight,
          child: WeekNowLine(axis: axis, date: DateTime.now()),
        ),
      ),
    );
    expect(find.byKey(WeekNowLine.lineKey), findsOneWidget);
    expect(find.byKey(WeekNowLine.dotKey), findsOneWidget);
    final line = tester.widget<ColoredBox>(find.byKey(WeekNowLine.lineKey));
    expect(line.color, AlmanacBrand.accentEnd);
  });

  testWidgets('tap on an empty slot selects a range without a dialog', (
    tester,
  ) async {
    WeekGridSlot? slot;
    var created = 0;
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final date = DateTime(2026, 9, 8);
    await tester.binding.setSurfaceSize(Size(240, axis.totalHeight + 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: axis.totalHeight,
            child: WeekTimedDayCanvas(
              date: date,
              axis: axis,
              events: const [],
              activeProfileId: 'default',
              profileSeedColors: const {},
              profileNamesById: const {},
              onEditEvent: (_) => created++,
              onSelectedSlotChanged: (value) => slot = value,
            ),
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(WeekTimedDayCanvas));
    await tester.tapAt(origin + Offset(80, axis.yForMinutes(10 * 60) + 2));
    await tester.pump();

    expect(created, 0);
    expect(slot, isNotNull);
    expect(slot!.isOnDate(date), isTrue);
    expect(slot!.startMinutes, 10 * 60);
    expect(slot!.endMinutes, 11 * 60);
  });

  testWidgets('selected slot shows frame and round handles', (tester) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    final date = DateTime(2026, 9, 8);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 200,
          height: axis.totalHeight,
          child: WeekTimedDayCanvas(
            date: date,
            axis: axis,
            events: const [],
            activeProfileId: 'default',
            profileSeedColors: const {},
            profileNamesById: const {},
            onEditEvent: (_) {},
            selectedSlot: WeekGridSlot.fromTap(
              date,
              const TimeOfDay(hour: 9, minute: 0),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(WeekSelectionFrame.frameKey), findsOneWidget);
    expect(find.byKey(WeekSelectionFrame.startHandleKey), findsOneWidget);
    expect(find.byKey(WeekSelectionFrame.endHandleKey), findsOneWidget);
  });

  testWidgets('hour labels show HH:00 chips with outline', (tester) async {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAlmanacTheme(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        home: SizedBox(
          width: kWeekHourLabelWidth,
          height: axis.totalHeight,
          child: WeekHourLabels(axis: axis),
        ),
      ),
    );

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    final chip = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(WeekHourLabels),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = chip.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });

  testWidgets('slot end handle snaps to 15 minutes', (tester) async {
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

    await tester.drag(
      find.byKey(WeekSelectionFrame.endHandleKey),
      const Offset(0, kWeekHourHeight / 4 + 2),
    );
    await tester.pumpAndSettle();

    expect(slot!.startMinutes, 10 * 60);
    expect(slot!.endMinutes, 11 * 60 + 15);
  });

  testWidgets('first tap on an event arms a frame, second tap edits', (
    tester,
  ) async {
    final day = DateTime(2026, 9, 8);
    final event = AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 8, 10),
        end: DateTime(2026, 9, 8, 11),
      ),
      title: 'Встреча',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
    );
    final axis = WeekHourAxis.fromEvents(
      events: [event],
      hideEmptyHours: false,
      expanded: true,
    );
    String? armedId;
    var edited = 0;
    await tester.binding.setSurfaceSize(Size(240, axis.totalHeight + 80));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
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
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 800,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WeekDayColumn(
                    date: day,
                    events: [event],
                    selected: true,
                    activeProfileId: 'default',
                    onEditEvent: (_) => edited++,
                    axis: axis,
                    hideEmptyWeekHours: false,
                    forceFullHourAxis: true,
                    showHourLabels: false,
                    dragSession: WeekDragSession(
                      armedEventId: armedId,
                      onArmed: (value) => setState(() => armedId = value.id),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Встреча'), findsOneWidget);
    await tester.tap(find.byType(WeekHourEventTile));
    await tester.pump();

    expect(armedId, 'e1');
    expect(edited, 0);
    expect(find.byKey(WeekSelectionFrame.frameKey), findsOneWidget);

    await tester.tap(find.byType(WeekHourEventTile));
    await tester.pump();
    expect(edited, 1);
  });
}
