import '../calendar/calendar_types.dart';
import '../data/events/recurrence_exdate.dart';

/// Минимальный экспорт событий в формат iCalendar (.ics).
final class IcsCalendarExport {
  IcsCalendarExport._();

  static String exportEvents(
    Iterable<AppEvent> events, {
    String calendarName = 'Almanac',
  }) {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//Almanac//Calendar//EN')
      ..writeln('X-WR-CALNAME:${_escapeText(calendarName)}');

    for (final event in events) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@almanac');
      buffer.writeln('SUMMARY:${_escapeText(event.title)}');
      buffer.writeln('DTSTART:${_formatUtc(event.start)}');
      buffer.writeln('DTEND:${_formatUtc(event.end)}');
      final notes = event.notes?.trim();
      if (notes != null && notes.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${_escapeText(notes)}');
      }
      final baseRrule = RecurrenceExdateCodec.baseRrule(event.rrule);
      if (baseRrule != null && baseRrule.isNotEmpty) {
        buffer.writeln('RRULE:$baseRrule');
      }
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _escapeText(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }
}
