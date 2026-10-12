import 'package:flutter/material.dart';

import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../../event_time_utils.dart';

/// Выделенный интервал на недельной сетке (ещё не сохранённая запись).
@immutable
class WeekGridSlot {
  const WeekGridSlot({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
  });

  factory WeekGridSlot.fromTap(DateTime date, TimeOfDay time) {
    final raw = time.hour * 60 + time.minute;
    final start = weekHourFloorMinutes(raw).clamp(
      0,
      24 * 60 - kWeekDefaultTimedDurationMinutes,
    );
    final end = (start + kWeekDefaultTimedDurationMinutes).clamp(
      start + kWeekTimeSnapMinutes,
      24 * 60,
    );
    return WeekGridSlot(
      date: calendarDayKey(date),
      startMinutes: start,
      endMinutes: end,
    );
  }

  final DateTime date;
  final int startMinutes;
  final int endMinutes;

  TimeOfDay get startTime => timeOfDayFromMinutes(startMinutes);

  TimeOfDay get endTime {
    if (endMinutes >= 24 * 60) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
    return timeOfDayFromMinutes(endMinutes);
  }

  bool get endsNextDay => endMinutes >= 24 * 60;

  bool isOnDate(DateTime other) => isSameCalendarDay(date, other);

  /// Same duration, new day / start (clamped to the day).
  WeekGridSlot movedTo({
    required DateTime date,
    required int startMinutes,
  }) {
    final duration = (endMinutes - this.startMinutes).clamp(
      kWeekTimeSnapMinutes,
      24 * 60,
    );
    final start = startMinutes.clamp(0, 24 * 60 - kWeekTimeSnapMinutes);
    final end = (start + duration).clamp(
      start + kWeekTimeSnapMinutes,
      24 * 60,
    );
    return WeekGridSlot(
      date: calendarDayKey(date),
      startMinutes: start,
      endMinutes: end,
    );
  }

  WeekGridSlot copyWith({
    DateTime? date,
    int? startMinutes,
    int? endMinutes,
  }) {
    return WeekGridSlot(
      date: date ?? this.date,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WeekGridSlot &&
        isSameCalendarDay(date, other.date) &&
        startMinutes == other.startMinutes &&
        endMinutes == other.endMinutes;
  }

  @override
  int get hashCode =>
      Object.hash(date.year, date.month, date.day, startMinutes, endMinutes);
}

/// Призрак слота, куда встанет карточка при переносе.
@immutable
class WeekDropPreview {
  const WeekDropPreview({
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
  });

  factory WeekDropPreview.fromEvent({
    required DateTime date,
    required AppEvent event,
    required int startMinutes,
  }) {
    final duration =
        (eventDisplayEndMinutesOfDay(event) - eventStartMinutesOfDay(event))
            .clamp(kWeekTimeSnapMinutes, 24 * 60);
    final start = startMinutes.clamp(0, 24 * 60 - kWeekTimeSnapMinutes);
    return WeekDropPreview(
      date: calendarDayKey(date),
      startMinutes: start,
      endMinutes: (start + duration).clamp(start + kWeekTimeSnapMinutes, 24 * 60),
    );
  }

  factory WeekDropPreview.fromSlot({
    required DateTime date,
    required WeekGridSlot slot,
    required int startMinutes,
  }) {
    final moved = slot.movedTo(date: date, startMinutes: startMinutes);
    return WeekDropPreview(
      date: moved.date,
      startMinutes: moved.startMinutes,
      endMinutes: moved.endMinutes,
    );
  }

  static const previewKey = ValueKey('week-drop-preview');

  final DateTime date;
  final int startMinutes;
  final int endMinutes;

  bool isOnDate(DateTime other) => isSameCalendarDay(date, other);
}
