import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';
import 'package:almanac/calendar/calendar_types.dart';

AppEvent _note({required String title, String? notes}) {
  return AppEvent(
    id: 'n1',
    kind: CalendarEntryKind.note,
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 6, 26),
      end: DateTime(2026, 6, 26),
    ),
    title: title,
    startTime: '',
    endTime: '',
    color: Colors.blue,
    notes: notes,
    checklist: const [],
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  test('deriveNoteTitleFromBody uses first line', () {
    expect(
      deriveNoteTitleFromBody('Первая строка\nВторая строка'),
      'Первая строка',
    );
  });

  test('auto derived note shows body once in display helpers', () {
    const body = 'Купить молоко\nИ хлеб';
    final event = _note(title: 'Купить молоко', notes: body);

    expect(event.isAutoDerivedNoteTitle, isTrue);
    expect(event.noteDisplayTitle, body);
    expect(event.noteDisplaySecondary, isNull);
  });

  test('custom note title shows title and body separately', () {
    const body = 'Купить молоко\nИ хлеб';
    final event = _note(title: 'Покупки', notes: body);

    expect(event.isAutoDerivedNoteTitle, isFalse);
    expect(event.noteDisplayTitle, 'Покупки');
    expect(event.noteDisplaySecondary, body);
  });
}
