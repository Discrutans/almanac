import '../../calendar/calendar_types.dart';

/// RFC 5545 EXDATE вместе с RRULE в поле хранения `rrule`.
abstract final class RecurrenceExdateCodec {
  static const _exdatePrefix = 'EXDATE:';

  /// Разбирает сохранённое значение `rrule` (RRULE + EXDATE строки).
  static ({String? rrule, List<DateTime> exdates}) parseStored(String? stored) {
    if (stored == null || stored.trim().isEmpty) {
      return (rrule: null, exdates: const []);
    }

    String? rrule;
    final exdates = <DateTime>[];

    for (final rawLine in stored.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final upper = line.toUpperCase();
      if (upper.startsWith('RRULE:')) {
        rrule = line.substring(6).trim();
        continue;
      }
      if (upper.startsWith(_exdatePrefix)) {
        exdates.addAll(
          _parseExdatePayload(line.substring(_exdatePrefix.length)),
        );
        continue;
      }
      if (upper.startsWith('FREQ=')) {
        rrule = line;
      }
    }

    return (rrule: rrule, exdates: exdates);
  }

  /// Базовая RRULE-строка без EXDATE (для парсера повторений).
  static String? baseRrule(String? stored) => parseStored(stored).rrule;

  /// Объединяет EXDATE из RRULE и JSON `recurrenceExclusions`.
  static List<DateTime> mergeExclusionDays(
    Iterable<DateTime> fromExdate,
    Iterable<DateTime> fromJson,
  ) {
    final merged = <DateTime>[];
    final seen = <int>{};

    for (final day in [...fromExdate, ...fromJson]) {
      final key = AppEvent.recurrenceDayKey(day);
      final stamp = key.millisecondsSinceEpoch;
      if (seen.add(stamp)) {
        merged.add(key);
      }
    }

    merged.sort((a, b) => a.compareTo(b));
    return merged;
  }

  /// Добавляет календарный день в список исключений (без дубликатов).
  static List<DateTime> addExclusionDay(
    List<DateTime> current,
    DateTime instanceStart,
  ) {
    final dayKey = AppEvent.recurrenceDayKey(instanceStart);
    if (current.any((day) => AppEvent.recurrenceDayKey(day) == dayKey)) {
      return current;
    }
    return [...current, dayKey]..sort((a, b) => a.compareTo(b));
  }

  /// Кодирует RRULE + EXDATE для snapshot (EXDATE с временем мастер-события).
  static String? encodeStored({
    required String? rrule,
    required List<DateTime> exclusionDays,
    required DateTime seriesStart,
  }) {
    if (rrule == null || rrule.isEmpty) return null;

    final buffer = StringBuffer(rrule);
    final seen = <int>{};
    final localStart = seriesStart.toLocal();

    for (final day in exclusionDays) {
      final dayKey = AppEvent.recurrenceDayKey(day);
      final stamp = dayKey.millisecondsSinceEpoch;
      if (!seen.add(stamp)) continue;

      final instance = DateTime(
        dayKey.year,
        dayKey.month,
        dayKey.day,
        localStart.hour,
        localStart.minute,
        localStart.second,
      );
      buffer.write('\n${_formatExdateLine(instance)}');
    }

    return buffer.toString();
  }

  static List<DateTime> _parseExdatePayload(String payload) {
    final values = payload.split(',');
    final parsed = <DateTime>[];

    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;

      final normalized = value.endsWith('Z')
          ? value.substring(0, value.length - 1)
          : value;

      final match = RegExp(
        r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2}))?$',
      ).firstMatch(normalized);
      if (match == null) continue;

      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4) ?? '0');
      final minute = int.parse(match.group(5) ?? '0');
      final second = int.parse(match.group(6) ?? '0');

      parsed.add(
        AppEvent.recurrenceDayKey(
          DateTime(year, month, day, hour, minute, second),
        ),
      );
    }

    return parsed;
  }

  static String _formatExdateLine(DateTime localInstance) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${localInstance.year}${two(localInstance.month)}${two(localInstance.day)}'
        'T${two(localInstance.hour)}${two(localInstance.minute)}${two(localInstance.second)}';
    return '$_exdatePrefix$stamp';
  }
}
