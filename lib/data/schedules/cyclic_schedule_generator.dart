import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import '../../calendar/calendar_event_index.dart';
import '../../calendar/calendar_types.dart';
import '../holidays/russian_holidays.dart';
import '../profiles/context_profile.dart';
import '../events/recurrence_engine.dart';

/// Генерирует календарные события из правил циклического расписания.
final class CyclicScheduleEventGenerator {
  CyclicScheduleEventGenerator._();

  /// Преобразует RRULE-расписание в мастер-событие.
  static AppEvent toMasterEvent(
    CyclicWorkSchedule schedule, {
    DateTime? anchor,
  }) {
    final start = _parseTime(schedule.startTime);
    final end = _parseTime(schedule.endTime);
    final base = anchor ?? DateTime.now();
    final anchorDate = DateTime(
      base.year,
      base.month,
      base.day,
      start.hour,
      start.minute,
    );

    return AppEvent(
      id: 'schedule-${schedule.id}',
      dateTimeRange: DateTimeRange(
        start: anchorDate,
        end: DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day,
          end.hour,
          end.minute,
        ),
      ),
      title: schedule.title,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      color: Color(schedule.colorValue),
      rrule: schedule.rrule,
      seriesId: 'schedule-${schedule.id}',
      interaction: EventInteraction.allowNone(),
    );
  }

  /// Разворачивает все расписания профиля во вхождения для диапазона.
  static List<AppEvent> expandForRange({
    required List<CyclicWorkSchedule> schedules,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final result = <AppEvent>[];

    for (final schedule in schedules) {
      if (schedule.isShiftCycle) {
        result.addAll(_expandShiftCycle(schedule, rangeStart, rangeEnd));
      } else {
        final master = toMasterEvent(schedule, anchor: rangeStart);
        result.addAll(
          RecurrenceEngine.expandEvent(
            master,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ).map(
            (event) => event.copyWith(
              id: 'schedule-${schedule.id}-${event.start.millisecondsSinceEpoch}',
            ),
          ),
        );
      }
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  /// Мастер-события для проверки конфликтов.
  static List<AppEvent> masterEvents(List<CyclicWorkSchedule> schedules) {
    final result = <AppEvent>[];
    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month, 1);
    final windowEnd = DateTime(now.year + 1, now.month + 1, 1);

    for (final schedule in schedules) {
      if (schedule.isShiftCycle) {
        result.addAll(_expandShiftCycle(schedule, windowStart, windowEnd));
      } else if (schedule.rrule.isNotEmpty) {
        result.add(toMasterEvent(schedule));
      }
    }

    return result;
  }

  /// Разворачивает сменный график N/M от [cycleStartDate].
  static List<AppEvent> _expandShiftCycle(
    CyclicWorkSchedule schedule,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final cycleStart = schedule.cycleStartDate;
    if (cycleStart == null) return [];
    if (schedule.workDays <= 0 || schedule.restDays <= 0) return [];

    final cycleLength = schedule.workDays + schedule.restDays;
    final start = _dateOnly(cycleStart);
    final startTime = _parseTime(schedule.startTime);
    final endTime = _parseTime(schedule.endTime);

    final events = <AppEvent>[];
    var day = _dateOnly(rangeStart);
    final end = _dateOnly(rangeEnd);

    while (day.isBefore(end)) {
      final dayIndex = day.difference(start).inDays;
      if (dayIndex >= 0 && dayIndex % cycleLength < schedule.workDays) {
        events.add(_eventOnDay(schedule, day, startTime, endTime));
      }
      day = day.add(const Duration(days: 1));
    }

    return events;
  }

  static AppEvent _eventOnDay(
    CyclicWorkSchedule schedule,
    DateTime day,
    TimeOfDay startTime,
    TimeOfDay endTime,
  ) {
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      startTime.hour,
      startTime.minute,
    );
    final end = DateTime(
      day.year,
      day.month,
      day.day,
      endTime.hour,
      endTime.minute,
    );

    return AppEvent(
      id: 'schedule-${schedule.id}-${start.millisecondsSinceEpoch}',
      dateTimeRange: DateTimeRange(start: start, end: end),
      title: schedule.title,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
      color: Color(schedule.colorValue),
      seriesId: 'schedule-${schedule.id}',
      interaction: EventInteraction.allowNone(),
    );
  }

  static DateTime _dateOnly(DateTime date) => calendarDayKey(date);

  static TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);

    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
}

/// Возвращает true, если [date] — рабочий день по сменному графику.
bool isShiftWorkDay({
  required DateTime cycleStartDate,
  required int workDays,
  required int restDays,
  required DateTime date,
}) {
  if (workDays <= 0 || restDays <= 0) return false;

  final cycleLength = workDays + restDays;
  final start = DateTime(
    cycleStartDate.year,
    cycleStartDate.month,
    cycleStartDate.day,
  );

  final day = DateTime(date.year, date.month, date.day);

  final dayIndex = day.difference(start).inDays;

  if (dayIndex < 0) return false;
  return dayIndex % cycleLength < workDays;
}

/// Считает рабочие дни сменного графика, попадающие на праздники РФ.
int countShiftDaysOnHolidays({
  required DateTime cycleStartDate,
  required int workDays,
  required int restDays,
  required DateTime from,
  required DateTime to,
}) {
  if (workDays <= 0 || restDays <= 0) return 0;

  final cycleLength = workDays + restDays;
  final start = DateTime(
    cycleStartDate.year,
    cycleStartDate.month,
    cycleStartDate.day,
  );
  var day = DateTime(from.year, from.month, from.day);

  final end = DateTime(to.year, to.month, to.day);
  var count = 0;

  while (!day.isAfter(end)) {
    final dayIndex = day.difference(start).inDays;
    if (dayIndex >= 0 &&
        dayIndex % cycleLength < workDays &&
        RussianHolidays.onDate(day) != null) {
      count++;
    }
    day = day.add(const Duration(days: 1));
  }

  return count;
}
