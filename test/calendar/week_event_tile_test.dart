// ignore_for_file: deprecated_member_use_from_same_package

import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/note_attachment.dart';
import 'package:almanac/calendar/widgets/week/week_event_tile.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

Widget _wrapTile(Widget child, {double width = 120}) {
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
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('week card shows user title instead of kind caption', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(120, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
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
              width: 120,
              child: WeekEventTile(
                event: AppEvent(
                  id: 'cl-1',
                  dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 9, 9)),
                  title: 'Покупки на неделю',
                  startTime: '',
                  endTime: '',
                  color: Colors.teal,
                  kind: CalendarEntryKind.checklist,
                  checklist: const [
                    ChecklistItem(id: 'a', title: 'Молоко'),
                    ChecklistItem(id: 'b', title: 'Хлеб', completed: true),
                  ],
                  interaction: EventInteraction.allowNone(),
                ),
                activeProfileId: 'default',
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Чек-лист'), findsNothing);
    expect(find.text('Покупки на неделю'), findsOneWidget);
    expect(find.text('Чек-листы: 1 из 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week card shows photo count separately from file count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
          body: WeekEventTile(
            event: AppEvent(
              id: 'note-1',
              dateTimeRange: AppEvent.dateOnlyRange(DateTime(2026, 9, 9)),
              title: 'Идея',
              startTime: '',
              endTime: '',
              color: Colors.orange,
              kind: CalendarEntryKind.note,
              attachments: const [
                NoteAttachment(
                  id: 'p1',
                  fileName: 'shot.jpg',
                  storagePath: 'shot.jpg',
                  mimeType: 'image/jpeg',
                ),
                NoteAttachment(
                  id: 'f1',
                  fileName: 'doc.pdf',
                  storagePath: 'doc.pdf',
                  mimeType: 'application/pdf',
                ),
              ],
              interaction: EventInteraction.allowNone(),
            ),
            activeProfileId: 'default',
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Заметка'), findsNothing);
    expect(find.text('Идея'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_outlined), findsOneWidget);
  });

  testWidgets('week card time uses the same font size as the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(120, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapTile(
        WeekEventTile(
          event: AppEvent(
            id: 'timed-1',
            dateTimeRange: DateTimeRange(
              start: DateTime(2026, 9, 10, 10, 46),
              end: DateTime(2026, 9, 10, 12, 46),
            ),
            title: 'Встреча',
            startTime: '10:46',
            endTime: '12:46',
            color: Colors.indigo,
            kind: CalendarEntryKind.event,
            interaction: EventInteraction.allowNone(),
          ),
          activeProfileId: 'default',
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Встреча'));
    final time = tester.widget<Text>(find.text('10:46 – 12:46'));
    expect(title.style?.fontSize, 14);
    expect(time.style?.fontSize, 14);
    expect(time.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week pomodoro shows full time and phase on a narrow column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(120, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapTile(
        WeekEventTile(
          event: AppEvent(
            id: 'pomo-1',
            dateTimeRange: DateTimeRange(
              start: DateTime(2026, 9, 10, 10),
              end: DateTime(2026, 9, 10, 12),
            ),
            title: 'Фокус',
            startTime: '10:00',
            endTime: '12:00',
            color: Colors.blue,
            kind: CalendarEntryKind.event,
            pomodoroEnabled: true,
            interaction: EventInteraction.allowNone(),
          ),
          activeProfileId: 'default',
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final time = tester.widget<Text>(find.text('25:00'));
    final phase = tester.widget<Text>(find.text('Работа'));
    expect(time.overflow, TextOverflow.visible);
    expect(phase.overflow, TextOverflow.visible);
    expect(tester.getRect(find.text('25:00')).width, lessThanOrEqualTo(120));
    expect(tester.getRect(find.text('Работа')).width, lessThanOrEqualTo(120));
    expect(tester.takeException(), isNull);
  });
}
