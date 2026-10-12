import 'package:flutter/material.dart';
import '../../calendar/calendar_types.dart';

/// Подписка на read-only внешний календарь (.ics по URL).
class GuestCalendarSubscription {
  const GuestCalendarSubscription({
    required this.id,
    required this.profileId,
    required this.title,
    required this.url,
    this.colorValue,
    required this.subscribedAt,
    this.cachedEvents = const [],
  });

  final String id;
  final String profileId;
  final String title;
  final String url;
  final int? colorValue;
  final DateTime subscribedAt;
  final List<AppEvent> cachedEvents;

  GuestCalendarSubscription copyWith({
    String? id,
    String? profileId,
    String? title,
    String? url,
    int? colorValue,
    DateTime? subscribedAt,
    List<AppEvent>? cachedEvents,
  }) {
    return GuestCalendarSubscription(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      url: url ?? this.url,
      colorValue: colorValue ?? this.colorValue,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      cachedEvents: cachedEvents ?? this.cachedEvents,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'title': title,
    'url': url,
    if (colorValue != null) 'colorValue': colorValue,
    'subscribedAt': subscribedAt.toIso8601String(),
    'cachedEvents': cachedEvents.map(_eventToJson).toList(),
  };

  factory GuestCalendarSubscription.fromJson(Map<String, dynamic> json) {
    return GuestCalendarSubscription(
      id: json['id'] as String,
      profileId: json['profileId'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      colorValue: (json['colorValue'] as num?)?.toInt(),
      subscribedAt: DateTime.parse(json['subscribedAt'] as String),
      cachedEvents: (json['cachedEvents'] as List<dynamic>? ?? const [])
          .map((value) => _eventFromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _eventToJson(AppEvent event) {
    return {
      'id': event.id,
      'title': event.title,
      'start': event.start.toIso8601String(),
      'end': event.end.toIso8601String(),
      'startTime': event.startTime,
      'endTime': event.endTime,
      'kind': event.kind.name,
      'colorValue': event.color.toARGB32(),
      if (event.notes != null) 'notes': event.notes,
    };
  }

  static AppEvent _eventFromJson(Map<String, dynamic> json) {
    return AppEvent(
      id: json['id'] as String,
      dateTimeRange: DateTimeRange(
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
      ),
      title: json['title'] as String,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      color: Color((json['colorValue'] as num?)?.toInt() ?? 0xFF607D8B),
      kind: CalendarEntryKind.values.byName(
        json['kind'] as String? ?? CalendarEntryKind.event.name,
      ),
      notes: json['notes'] as String?,
    );
  }
}
