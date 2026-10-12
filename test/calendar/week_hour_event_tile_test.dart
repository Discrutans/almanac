import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:almanac/calendar/widgets/week/week_hour_event_tile.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

WeekHourAxis _axisFor(AppEvent event) {
  return WeekHourAxis.fromEvents(
    events: [event],
    hideEmptyHours: false,
    expanded: true,
  );
}

void main() {
  testWidgets('hour cell shows title and start time without type icon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 10, 10),
        end: DateTime(2026, 9, 10, 11),
      ),
      title: 'Встреча',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
      interaction: EventInteraction.allowNone(),
    );
    final axis = _axisFor(event);

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
            body: Center(
              child: SizedBox(
                width: 160,
                height: axis.hourHeight,
                child: WeekHourEventTile(
                  event: event,
                  axis: axis,
                  startMinutes: 10 * 60,
                  endMinutes: 11 * 60,
                  activeProfileId: 'default',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WeekHourEventTile), findsOneWidget);
    expect(find.text('Встреча'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('10:00 - 11:00'), findsNothing);
    expect(find.byIcon(Icons.event_outlined), findsNothing);
  });

  testWidgets('tall event shows full time range', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = AppEvent(
      id: 'e2',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 10, 10),
        end: DateTime(2026, 9, 10, 13),
      ),
      title: 'Длинная',
      startTime: '10:00',
      endTime: '13:00',
      color: Colors.teal,
      interaction: EventInteraction.allowNone(),
    );
    final axis = _axisFor(event);

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
            body: Center(
              child: SizedBox(
                width: 160,
                height: axis.hourHeight * 3,
                child: WeekHourEventTile(
                  event: event,
                  axis: axis,
                  startMinutes: 10 * 60,
                  endMinutes: 13 * 60,
                  activeProfileId: 'default',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Длинная'), findsOneWidget);
    expect(find.text('10:00 - 13:00'), findsOneWidget);
  });

  testWidgets('locked hour cell shows lock icon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = AppEvent(
      id: 'lock-1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 10, 10),
        end: DateTime(2026, 9, 10, 11),
      ),
      title: 'Смена',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
      interaction: EventInteraction.allowNone(),
    );
    final axis = _axisFor(event);

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
            body: Center(
              child: SizedBox(
                width: 160,
                height: 56,
                child: WeekHourEventTile(
                  event: event,
                  axis: axis,
                  startMinutes: 10 * 60,
                  endMinutes: 11 * 60,
                  activeProfileId: 'default',
                  locked: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('locked cascade strip does not overflow at 8px text width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final event = AppEvent(
      id: 'lock-narrow',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 10, 10),
        end: DateTime(2026, 9, 10, 11),
      ),
      title: 'Смена',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.teal,
      interaction: EventInteraction.allowNone(),
    );
    final axis = _axisFor(event);

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
            body: Center(
              child: SizedBox(
                width: 90,
                height: axis.hourHeight,
                child: WeekHourEventTile(
                  event: event,
                  axis: axis,
                  startMinutes: 10 * 60,
                  endMinutes: 11 * 60,
                  contentMaxWidth: 8,
                  activeProfileId: 'default',
                  locked: true,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });
}
