import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/forms/edit_event_dialog.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/core/ui/almanac_buttons.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

Widget _app({required Widget home}) {
  return MaterialApp(
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('schedule edit warns on personal overlap but still allows save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final day = DateTime(2026, 6, 3);
    final scheduleEvent = AppEvent(
      id: 'schedule-shift-${day.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 3, 8),
        end: DateTime(2026, 6, 3, 17),
      ),
      title: 'Смена',
      startTime: '08:00',
      endTime: '17:00',
      color: Colors.teal,
      seriesId: 'schedule-shift',
      interaction: EventInteraction.allowNone(),
    );
    final personal = AppEvent(
      id: 'meet',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 6, 3, 18),
        end: DateTime(2026, 6, 3, 19),
      ),
      title: 'Meet',
      startTime: '18:00',
      endTime: '19:00',
      color: Colors.orange,
      interaction: EventInteraction.allowNone(),
    );

    AppEvent? saved;
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EditEventDialog(
              event: scheduleEvent,
              existingEvents: [scheduleEvent, personal],
              onSave: (event, {recurrenceScope = RecurrenceEditScope.wholeSeries}) async {
                saved = event;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Extend shift into personal meeting (18:00–19:00).
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    final endField = fields.firstWhere(
      (field) => field.controller?.text == '17:00',
    );
    await tester.enterText(find.byWidget(endField), '20:00');
    await tester.pumpAndSettle();

    expect(
      find.text('Это время пересекается с другим событием'),
      findsOneWidget,
    );
    expect(
      find.text('Конфликт: время пересекается с другим событием'),
      findsNothing,
    );

    await tester.tap(find.byType(AlmanacAsyncFilledButton));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.endTime, '20:00');
  });
}
