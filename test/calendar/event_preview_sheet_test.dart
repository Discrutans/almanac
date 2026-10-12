import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/event_preview_sheet.dart';
import 'package:almanac/data/events/recurrence_engine.dart';
import 'package:almanac/calendar/widgets/forms/edit_event_dialog.dart';
import 'package:almanac/calendar/widgets/week/week_day_column.dart';
import 'package:almanac/calendar/widgets/week/week_hour_event_tile.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _timedEvent() {
  return AppEvent(
    id: 'preview-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 10, 10, 46),
      end: DateTime(2026, 9, 10, 12, 46),
    ),
    title: 'Встреча',
    startTime: '10:46',
    endTime: '12:46',
    color: Colors.indigo,
    kind: CalendarEntryKind.event,
    notes: 'Обсудить смету',
    interaction: EventInteraction.allowNone(),
  );
}

Widget _app(Widget home) {
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
  testWidgets('preview sheet shows event details without the editor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(EventPreviewSheet), findsOneWidget);
    expect(find.text('Встреча'), findsOneWidget);
    expect(find.text('10:46 - 12:46'), findsOneWidget);
    expect(find.text('Обсудить смету'), findsOneWidget);
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Редактировать событие'), findsNothing);
    expect(find.text('Сохранить'), findsNothing);
  });

  testWidgets('edit button reveals the form in the same sheet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();

    expect(find.byType(EventPreviewSheet), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Изменить'), findsNothing);
    expect(find.text('Редактировать событие'), findsNothing);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.byType(EditEventDialog), findsNothing);
    expect(find.byType(EventPreviewSheet), findsOneWidget);
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Сохранить'), findsNothing);
  });

  testWidgets('week tile tap opens preview instead of editor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) {
              return SizedBox(
                width: 200,
                height: 500,
                child: WeekDayColumn(
                  date: DateTime(2026, 9, 10),
                  events: [_timedEvent()],
                  selected: true,
                  activeProfileId: 'default',
                  onEditEvent: (event) {
                    EventPreviewSheet.show(
                      context: context,
                      event: event,
                      activeProfileId: 'default',
                      onSave:
                          (
                            _, {
                            recurrenceScope = RecurrenceEditScope.wholeSeries,
                          }) async {},
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Встреча'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Встреча'));
    await tester.pumpAndSettle();

    expect(find.byType(EventPreviewSheet), findsOneWidget);
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Редактировать событие'), findsNothing);
    expect(find.text('Сохранить'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview sheet fills the window', (tester) async {
    const viewport = Size(400, 800);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Событие'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Событие')).dy, lessThan(80));
    expect(tester.getTopLeft(find.text('Изменить')).dy, lessThan(160));
    expect(
      tester.getBottomLeft(find.text('Изменить')).dy,
      lessThan(viewport.height * 0.35),
    );
    expect(
      tester.getTopLeft(find.text('Изменить')).dx,
      greaterThan(viewport.width * 0.45),
    );
  });

  testWidgets('startInEdit opens the form immediately', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  EventPreviewSheet.show(
                    context: context,
                    event: _timedEvent(),
                    activeProfileId: 'default',
                    startInEdit: true,
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(EventPreviewSheet), findsOneWidget);
    expect(find.byType(EditEventDialog), findsOneWidget);
    expect(find.text('Сохранить'), findsOneWidget);
    expect(find.text('Изменить'), findsNothing);
  });

  testWidgets('failed edit lock stays in preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  EventPreviewSheet.show(
                    context: context,
                    event: _timedEvent(),
                    activeProfileId: 'default',
                    acquireEditLock: () async => false,
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();

    expect(find.byType(EditEventDialog), findsNothing);
    expect(find.text('Изменить'), findsOneWidget);
    expect(
      find.text(
        'Сейчас это событие правит другое устройство. Подождите или откройте просмотр.',
      ),
      findsOneWidget,
    );
  });
}
