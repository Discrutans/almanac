import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_day_column.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_event_tile.dart';
import 'package:almanac/calendar/widgets/week/week_move_controller.dart';
import 'package:almanac/calendar/widgets/week/week_move_scope.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _shift() {
  final day = DateTime(2026, 9, 8);
  return AppEvent(
    id: 'schedule-abc-${day.millisecondsSinceEpoch}',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 8, 10),
      end: DateTime(2026, 9, 8, 12),
    ),
    title: 'Смена',
    startTime: '10:00',
    endTime: '12:00',
    color: Colors.teal,
    seriesId: 'schedule-abc',
    interaction: EventInteraction.allowNone(),
  );
}

Widget _harness({required WeekMoveController move}) {
  final event = _shift();
  return ProviderScope(
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
        body: WeekMoveScope(
          controller: move,
          child: SizedBox(
            width: 200,
            height: 800,
            child: WeekDayColumn(
              date: DateTime(2026, 9, 8),
              events: [event],
              selected: true,
              activeProfileId: 'default',
              onEditEvent: (_) {},
              moveEnabled: true,
              axis: WeekHourAxis.fromEvents(
                events: [event],
                hideEmptyHours: false,
                expanded: true,
              ),
              hideEmptyWeekHours: false,
              forceFullHourAxis: true,
              showHourLabels: false,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('short drag on locked shift does not offer a move', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final move = WeekMoveController(resolveTarget: (_) => null);
    addTearDown(move.dispose);
    await tester.pumpWidget(_harness(move: move));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.drag(find.byType(WeekHourEventTile), const Offset(0, 60));
    await tester.pumpAndSettle();

    expect(move.hasPendingCandidate, isFalse);
    expect(move.active, isFalse);
  });

  testWidgets('one-second hold on locked shift offers unlock candidate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final move = WeekMoveController(resolveTarget: (_) => null);
    addTearDown(move.dispose);
    await tester.pumpWidget(_harness(move: move));
    await tester.pumpAndSettle();

    final center = tester.getCenter(find.byType(WeekHourEventTile));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(move.hasPendingCandidate, isTrue);
    await gesture.up();
  });
}
