import '../../calendar/calendar_types.dart';

/// Быстрый шаблон для создания записи календаря.
class EventQuickTemplate {
  const EventQuickTemplate({
    required this.id,
    required this.title,
    this.kind = CalendarEntryKind.event,
    this.durationMinutes = 60,
    this.colorValue,
    this.notesHint,
  });

  final String id;
  final String title;
  final CalendarEntryKind kind;
  final int durationMinutes;
  final int? colorValue;
  final String? notesHint;

  EventQuickTemplate copyWith({
    String? id,
    String? title,
    CalendarEntryKind? kind,
    int? durationMinutes,
    int? colorValue,
    String? notesHint,
  }) {
    return EventQuickTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      colorValue: colorValue ?? this.colorValue,
      notesHint: notesHint ?? this.notesHint,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'durationMinutes': durationMinutes,
    if (colorValue != null) 'colorValue': colorValue,
    if (notesHint != null && notesHint!.isNotEmpty) 'notesHint': notesHint,
  };

  factory EventQuickTemplate.fromJson(Map<String, dynamic> json) {
    return EventQuickTemplate(
      id: json['id'] as String,
      title: json['title'] as String,
      kind: CalendarEntryKind.values.byName(
        json['kind'] as String? ?? CalendarEntryKind.event.name,
      ),
      durationMinutes: json['durationMinutes'] as int? ?? 60,
      colorValue: (json['colorValue'] as num?)?.toInt(),
      notesHint: json['notesHint'] as String?,
    );
  }
}
