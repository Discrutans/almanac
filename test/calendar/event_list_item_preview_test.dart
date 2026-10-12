import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/event_list_item.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _event() {
  return AppEvent(
    id: 'list-1',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 10, 10),
      end: DateTime(2026, 9, 10, 11),
    ),
    title: 'Карточка дня',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.teal,
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
  testWidgets('card tap views the event; no persistent edit button', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    AppEvent? viewed;
    AppEvent? edited;

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventListItem(
            event: _event(),
            activeProfileId: 'default',
            compactActions: true,
            onViewEvent: (event) => viewed = event,
            onEditEvent: (event) => edited = event,
            onDeleteEvent: (_) async => true,
            onEventUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Изменить'), findsNothing);
    expect(find.text('10:00 - 11:00'), findsOneWidget);

    await tester.tap(find.text('Карточка дня'));
    await tester.pumpAndSettle();
    expect(viewed?.id, 'list-1');
    expect(edited, isNull);
  });

  testWidgets('note uses the full card width for the body', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const title = 'Заметка · 3.9';
    const note =
        'Проверка заполнения заметок, списка, недели и карточек. '
        'Длинный текст для оценки обрезки, переносов и tooltip. '
        'Смена · чек-лист · накопление · событие · помодоро · доход.';

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventListItem(
            event: AppEvent(
              id: 'note-1',
              dateTimeRange: DateTimeRange(
                start: DateTime(2026, 9, 3),
                end: DateTime(2026, 9, 3),
              ),
              title: title,
              startTime: '00:00',
              endTime: '00:00',
              color: Colors.orange,
              kind: CalendarEntryKind.note,
              notes: note,
              interaction: EventInteraction.allowNone(),
            ),
            activeProfileId: 'default',
            dense: true,
            compactActions: true,
            onEditEvent: (_) {},
            onDeleteEvent: (_) async => true,
            onEventUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Изменить'), findsNothing);
    final titleBox = tester.getRect(find.text(title));
    final noteBox = tester.getRect(find.text(note));
    expect(noteBox.top, greaterThan(titleBox.bottom - 1));
  });

  testWidgets('month day card shows at most three lines of the note body', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const title = 'Заметка · месяц';
    const note =
        'Полный текст заметки для карточки дня в месяце. '
        'Первая строка не должна обрезаться многоточием. '
        'Вторая строка тоже должна быть видна целиком. '
        'Третья строка и всё, что дальше, остаются в карточке. '
        'Четвёртая и пятая строки подтверждают, что тело не режется.';

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventListItem(
            event: AppEvent(
              id: 'note-month-1',
              dateTimeRange: DateTimeRange(
                start: DateTime(2026, 9, 10),
                end: DateTime(2026, 9, 10),
              ),
              title: title,
              startTime: '00:00',
              endTime: '00:00',
              color: Colors.orange,
              kind: CalendarEntryKind.note,
              notes: note,
              interaction: EventInteraction.allowNone(),
            ),
            activeProfileId: 'default',
            compactActions: true,
            onEditEvent: (_) {},
            onDeleteEvent: (_) async => true,
            onEventUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(note), findsOneWidget);
    final noteText = tester.widget<Text>(find.text(note));
    expect(noteText.maxLines, 3);
    expect(noteText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('checklist body uses the full card width under the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const title = 'Чек-лист · 3.9';
    const itemTitle =
        'Длинный пункт чек-листа, который должен занять всю ширину карточки';

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventListItem(
            event: AppEvent(
              id: 'check-1',
              dateTimeRange: DateTimeRange(
                start: DateTime(2026, 9, 3),
                end: DateTime(2026, 9, 3),
              ),
              title: title,
              startTime: '00:00',
              endTime: '00:00',
              color: Colors.teal,
              kind: CalendarEntryKind.checklist,
              checklist: const [ChecklistItem(id: 'i1', title: itemTitle)],
              interaction: EventInteraction.allowNone(),
            ),
            activeProfileId: 'default',
            dense: true,
            compactActions: true,
            checklistsAlwaysExpanded: true,
            onEditEvent: (_) {},
            onDeleteEvent: (_) async => true,
            onEventUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Изменить'), findsNothing);
    final titleBox = tester.getRect(find.text(title));
    final itemBox = tester.getRect(find.text(itemTitle));
    expect(itemBox.top, greaterThan(titleBox.bottom - 1));
  });

  testWidgets('shift time sits above the title, not in the note body', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const title = 'Смена 2/2';
    const notes =
        'Длинный текст смены для проверки, что время не сливается с телом.';

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EventListItem(
            event: AppEvent(
              id: 'shift-1',
              dateTimeRange: DateTimeRange(
                start: DateTime(2026, 9, 10, 3, 17),
                end: DateTime(2026, 9, 10, 8, 17),
              ),
              title: title,
              startTime: '03:17',
              endTime: '08:17',
              color: Colors.green,
              notes: notes,
              interaction: EventInteraction.allowNone(),
            ),
            activeProfileId: 'default',
            dense: true,
            compactActions: true,
            onEditEvent: (_) {},
            onDeleteEvent: (_) async => true,
            onEventUpdated: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleBox = tester.getRect(find.text(title));
    final timeBox = tester.getRect(find.text('03:17 - 08:17'));
    final notesBox = tester.getRect(find.text(notes));

    expect(timeBox.bottom, lessThanOrEqualTo(titleBox.top + 1));
    expect(notesBox.top, greaterThan(titleBox.bottom - 1));
    expect(find.text('Изменить'), findsNothing);
  });

  testWidgets(
    'enableSwipe false keeps preview without slidable panes or edit pill',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AppEvent? viewed;
      AppEvent? edited;

      await tester.pumpWidget(
        _app(
          Scaffold(
            body: EventListItem(
              event: _event(),
              activeProfileId: 'default',
              dense: true,
              compactActions: true,
              enableSwipe: false,
              onViewEvent: (event) => viewed = event,
              onEditEvent: (event) => edited = event,
              onDeleteEvent: (_) async => true,
              onEventUpdated: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Slidable), findsNothing);
      expect(find.text('Изменить'), findsNothing);

      await tester.tap(find.text('Карточка дня'));
      await tester.pumpAndSettle();
      expect(viewed?.id, 'list-1');
      expect(edited, isNull);
    },
  );
}
