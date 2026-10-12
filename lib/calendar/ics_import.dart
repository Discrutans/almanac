import 'package:flutter/material.dart';
import '../calendar/calendar_types.dart';

/// Минимальный парсер iCalendar (.ics) для подписок.
final class IcsCalendarImport {
  IcsCalendarImport._();

  static List<AppEvent> parse(String ics, {required Color fallbackColor}) {
    final events = <AppEvent>[];
    final blocks = ics.split('BEGIN:VEVENT');
    for (final block in blocks.skip(1)) {
      final endIndex = block.indexOf('END:VEVENT');
      if (endIndex < 0) continue;
      final body = block.substring(0, endIndex);
      final fields = _parseFields(body);
      final summary = fields['SUMMARY'];
      final startRaw = fields['DTSTART'];
      if (summary == null || startRaw == null) continue;

      final start = _parseDateTime(startRaw);
      if (start == null) continue;
      final end =
          _parseDateTime(
            fields['DTEND'] ?? startRaw,
          )?.add(const Duration(hours: 1)) ??
          start.add(const Duration(hours: 1));
      final uid = fields['UID'] ?? 'guest-${events.length}';

      events.add(
        AppEvent(
          id: 'guest-$uid',
          dateTimeRange: DateTimeRange(start: start, end: end),
          title: summary,
          startTime: _formatTime(start),
          endTime: _formatTime(end),
          color: fallbackColor,
        ),
      );
    }
    return events;
  }

  static Map<String, String> _parseFields(String body) {
    final fields = <String, String>{};
    final lines = body.split('\n');
    String? currentKey;
    final buffer = StringBuffer();

    void flush() {
      if (currentKey == null) return;
      fields[currentKey] = _unescape(buffer.toString().trim());
      buffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.startsWith(' ') || line.startsWith('\t')) {
        buffer.write(line.trimLeft());
        continue;
      }
      flush();
      final colon = line.indexOf(':');
      if (colon <= 0) {
        currentKey = null;
        continue;
      }
      final keyPart = line.substring(0, colon);
      currentKey = keyPart.split(';').first;
      buffer.write(line.substring(colon + 1));
    }
    flush();
    return fields;
  }

  static DateTime? _parseDateTime(String raw) {
    final value = raw.trim();
    if (value.length >= 15 && value.endsWith('Z')) {
      final y = int.tryParse(value.substring(0, 4));
      final mo = int.tryParse(value.substring(4, 6));
      final d = int.tryParse(value.substring(6, 8));
      final h = int.tryParse(value.substring(9, 11));
      final mi = int.tryParse(value.substring(11, 13));
      final s = int.tryParse(value.substring(13, 15));
      if ([y, mo, d, h, mi, s].every((part) => part != null)) {
        return DateTime.utc(y!, mo!, d!, h!, mi!, s!).toLocal();
      }
    }
    if (value.length >= 8 && !value.contains('T')) {
      final y = int.tryParse(value.substring(0, 4));
      final mo = int.tryParse(value.substring(4, 6));
      final d = int.tryParse(value.substring(6, 8));
      if (y != null && mo != null && d != null) {
        return DateTime(y, mo, d);
      }
    }
    return DateTime.tryParse(value);
  }

  static String _formatTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}';
  }

  static String _unescape(String value) {
    return value
        .replaceAll('\\n', '\n')
        .replaceAll('\\,', ',')
        .replaceAll('\\;', ';')
        .replaceAll('\\\\', '\\');
  }
}
