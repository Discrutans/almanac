import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import '../../../core/localization/app_localizations.dart';

/// Общий разбор полей create/edit event forms (без setState).
final class EventFormParsing {
  const EventFormParsing._();

  static String resolveTitle({
    required CalendarEntryKind kind,
    required String titleRaw,
    required String notesRaw,
    required AppLocalizations l10n,
  }) {
    final title = titleRaw.trim();
    if (title.isNotEmpty) return title;

    switch (kind) {
      case CalendarEntryKind.note:
        final notes = notesRaw.trim();
        if (notes.isEmpty) return l10n.defaultNoteTitle;
        final derived = deriveNoteTitleFromBody(notes);
        return derived.isEmpty ? l10n.defaultNoteTitle : derived;
      case CalendarEntryKind.checklist:
        return l10n.defaultChecklistTitle;
      case CalendarEntryKind.event:
      case CalendarEntryKind.savingsGoal:
        return title;
    }
  }

  static String? notesOrNull(String notesRaw) {
    final notes = notesRaw.trim();
    return notes.isEmpty ? null : notes;
  }

  /// Возвращает amount или null; [error] заполняется при невалидном вводе.
  static ({double? amount, String? error}) parseIncomeAmount({
    required String raw,
    required AppLocalizations l10n,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return (amount: null, error: null);
    final amount = parseMoneyAmount(trimmed);
    if (amount == null) {
      return (amount: null, error: l10n.invalidAmount);
    }
    return (amount: amount, error: null);
  }

  /// По умолчанию 25/5, если pomodoro выключен или [forceDefaults].
  static ({int work, int breakMinutes, String? error}) parsePomodoroMinutes({
    required bool enabled,
    required String workRaw,
    required String breakRaw,
    required AppLocalizations l10n,
    bool forceDefaults = false,
  }) {
    if (!enabled || forceDefaults) {
      return (work: 25, breakMinutes: 5, error: null);
    }
    final work = int.tryParse(workRaw.trim()) ?? 0;
    final breakMinutes = int.tryParse(breakRaw.trim()) ?? 0;
    if (work < 1 || work > 180 || breakMinutes < 1 || breakMinutes > 180) {
      return (work: 0, breakMinutes: 0, error: l10n.invalidPomodoroMinutes);
    }
    return (work: work, breakMinutes: breakMinutes, error: null);
  }
}
