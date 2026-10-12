import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/forms/event_form_parsing.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizations.forLocale(const Locale('ru'));

  group('EventFormParsing.resolveTitle', () {
    test('keeps explicit title', () {
      expect(
        EventFormParsing.resolveTitle(
          kind: CalendarEntryKind.event,
          titleRaw: '  Meeting ',
          notesRaw: '',
          l10n: l10n,
        ),
        'Meeting',
      );
    });

    test('derives note title from body', () {
      expect(
        EventFormParsing.resolveTitle(
          kind: CalendarEntryKind.note,
          titleRaw: '',
          notesRaw: 'First line\nSecond',
          l10n: l10n,
        ),
        'First line',
      );
    });

    test('uses default checklist title when empty', () {
      expect(
        EventFormParsing.resolveTitle(
          kind: CalendarEntryKind.checklist,
          titleRaw: '  ',
          notesRaw: '',
          l10n: l10n,
        ),
        l10n.defaultChecklistTitle,
      );
    });
  });

  group('EventFormParsing.parseIncomeAmount', () {
    test('empty is ok null', () {
      final result = EventFormParsing.parseIncomeAmount(raw: '', l10n: l10n);
      expect(result.amount, isNull);
      expect(result.error, isNull);
    });

    test('parses valid money', () {
      final result = EventFormParsing.parseIncomeAmount(
        raw: '1 250,50',
        l10n: l10n,
      );
      expect(result.error, isNull);
      expect(result.amount, 1250.5);
    });

    test('rejects invalid money', () {
      final result = EventFormParsing.parseIncomeAmount(raw: 'abc', l10n: l10n);
      expect(result.amount, isNull);
      expect(result.error, l10n.invalidAmount);
    });
  });

  group('EventFormParsing.parsePomodoroMinutes', () {
    test('defaults when disabled', () {
      final result = EventFormParsing.parsePomodoroMinutes(
        enabled: false,
        workRaw: '99',
        breakRaw: '99',
        l10n: l10n,
      );
      expect(result.work, 25);
      expect(result.breakMinutes, 5);
      expect(result.error, isNull);
    });

    test('validates range when enabled', () {
      final bad = EventFormParsing.parsePomodoroMinutes(
        enabled: true,
        workRaw: '0',
        breakRaw: '5',
        l10n: l10n,
      );
      expect(bad.error, l10n.invalidPomodoroMinutes);

      final ok = EventFormParsing.parsePomodoroMinutes(
        enabled: true,
        workRaw: '30',
        breakRaw: '10',
        l10n: l10n,
      );
      expect(ok.error, isNull);
      expect(ok.work, 30);
      expect(ok.breakMinutes, 10);
    });
  });
}
