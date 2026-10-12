import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../calendar/calendar_event_index.dart';
import '../../platform/session_types.dart';

const _uuid = Uuid();

enum BookingScheduleKind { weekdays, cycle, dates }

class BookingScheduleConfig {
  const BookingScheduleConfig({
    required this.startDate,
    required this.horizonDays,
    required this.kind,
    required this.weekdays,
    required this.workDays,
    required this.restDays,
    required this.windowStart,
    required this.windowEnd,
    required this.intervalMinutes,
    this.dates = const {},
  });

  final DateTime startDate;
  final int horizonDays;
  final BookingScheduleKind kind;
  final Set<int> weekdays;
  final int workDays;
  final int restDays;
  final TimeOfDay windowStart;
  final TimeOfDay windowEnd;
  final int intervalMinutes;
  final Set<DateTime> dates;
}

DateTime _dateOnly(DateTime value) => calendarDayKey(value);

bool _isActiveDay(DateTime day, BookingScheduleConfig config) {
  final normalized = _dateOnly(day);

  if (config.kind == BookingScheduleKind.dates) {
    return config.dates.contains(normalized);
  }

  final start = _dateOnly(config.startDate);
  if (normalized.isBefore(start)) return false;

  if (config.kind == BookingScheduleKind.weekdays) {
    if (config.weekdays.isEmpty) return false;
    return config.weekdays.contains(normalized.weekday);
  }

  final cycleLength = config.workDays + config.restDays;
  if (cycleLength <= 0) return false;
  final dayIndex = normalized.difference(start).inDays;
  return dayIndex >= 0 && dayIndex % cycleLength < config.workDays;
}

List<SessionSlot> _slotsOnDay(DateTime day, BookingScheduleConfig config) {
  var cursor = DateTime(
    day.year,
    day.month,
    day.day,
    config.windowStart.hour,
    config.windowStart.minute,
  );
  final windowEnd = DateTime(
    day.year,
    day.month,
    day.day,
    config.windowEnd.hour,
    config.windowEnd.minute,
  );
  if (!windowEnd.isAfter(cursor)) return const [];

  final slots = <SessionSlot>[];
  while (true) {
    final slotEnd = cursor.add(Duration(minutes: config.intervalMinutes));
    if (slotEnd.isAfter(windowEnd)) break;
    slots.add(SessionSlot(id: _uuid.v4(), start: cursor, end: slotEnd));
    cursor = slotEnd;
  }
  return slots;
}

List<SessionSlot> generateBookingSlots(BookingScheduleConfig config) {
  if (config.intervalMinutes <= 0) return const [];

  if (config.kind == BookingScheduleKind.dates) {
    final days = config.dates.map(_dateOnly).toSet().toList()..sort();
    return [for (final day in days) ..._slotsOnDay(day, config)];
  }

  final slots = <SessionSlot>[];
  final start = _dateOnly(config.startDate);

  for (var offset = 0; offset < config.horizonDays; offset++) {
    final day = start.add(Duration(days: offset));
    if (!_isActiveDay(day, config)) continue;
    slots.addAll(_slotsOnDay(day, config));
  }

  return slots;
}
