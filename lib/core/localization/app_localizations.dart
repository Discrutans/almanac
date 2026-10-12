import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../booking/booking_types.dart';
import '../../calendar/calendar_types.dart';
import '../../calendar/event_time_utils.dart';
import '../../finance/pay_types.dart';
import '../../data/events/recurrence_engine.dart';
import '../../data/profiles/profile_kind.dart';

part 'strings_calendar.dart';
part 'strings_finance.dart';
part 'strings_sessions.dart';
part 'strings_common.dart';

/// Простая локализация без ARB-кодогенерации.
abstract class _LocalizationStringsBase {
  bool get isRu;
  String fullDate(DateTime date);
  String monthName(int month);
  String shortWeekday(int weekday);
  String weekday(int weekday);
  String agendaMonthYear(DateTime date);
  String get addSavingsGoal;
  String get editSavingsGoalTitle;
  String reminderLabel(int? minutes);
  String recurrencePresetLabel(RecurrencePreset preset);
  String get patternDaily;
  String get patternWeekly;
}

class AppLocalizations extends _LocalizationStringsBase
    with _CalendarStrings, _FinanceStrings, _SessionStrings, _CommonStrings {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ru'), Locale('en')];
  static const fallback = Locale('ru');

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  /// Локализация без [BuildContext] (сервисы, notifiers).
  static AppLocalizations forLocale(Locale locale) => AppLocalizations(locale);

  static Locale localeFromCode(String? languageCode) {
    if (languageCode == null) return fallback;
    return supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => fallback,
    );
  }

  static const delegate = _AppLocalizationsDelegate();

  @override
  bool get isRu => locale.languageCode == 'ru';

  String get invalidShiftDays => isRu
      ? 'Укажите рабочие и выходные дни больше 0'
      : 'Work and rest days must be greater than 0';
  String get schedulePatternTitle =>
      isRu ? 'График (рабочие / выходные дни)' : 'Pattern (work / rest days)';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (it) => it.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
