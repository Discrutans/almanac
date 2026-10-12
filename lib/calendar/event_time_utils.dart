import 'package:flutter/material.dart';
import '../core/ui/almanac_time_field.dart';
import 'calendar_types.dart';
import '../finance/pay_types.dart';

/// Минимальная длительность на календаре, если окончание не задано.
const Duration openEndedEventDuration = Duration(minutes: 15);

/// Шаг сетки недели и resize.
const int kWeekTimeSnapMinutes = 15;

/// Snap старта при tap-создании слота (целый час).
const int kWeekCreateSnapMinutes = 60;

/// Визуальная длительность события без конца на часовой сетке.
const int kWeekDefaultTimedDurationMinutes = 60;

/// Режим привязки минут на недельной сетке.
enum WeekMinuteSnapKind {
  /// Нижняя граница часовой ячейки под пальцем (create / empty-tap retarget).
  hourCell,

  /// Шаг [kWeekTimeSnapMinutes] (resize / drag-drop).
  grid,
}

bool eventHasKnownEndTime(AppEvent event) => event.endTime.trim().isNotEmpty;

String formatEventTimeRange(AppEvent event) {
  if (!eventHasKnownEndTime(event)) return event.startTime;
  return '${event.startTime} - ${event.endTime}';
}

int snapWeekMinutes(int minutes, {int step = kWeekTimeSnapMinutes}) {
  final safeStep = step <= 0 ? kWeekTimeSnapMinutes : step;
  final snapped = ((minutes / safeStep).round() * safeStep);
  return snapped.clamp(0, 24 * 60);
}

/// Целый час ячейки: 8:17 → 8:00 (не round к ближайшему).
int weekHourFloorMinutes(int minutes) =>
    (minutes.clamp(0, 24 * 60 - 1) ~/ 60) * 60;

int snapWeekByKind(int minutes, WeekMinuteSnapKind kind) => switch (kind) {
  WeekMinuteSnapKind.hourCell => weekHourFloorMinutes(minutes),
  WeekMinuteSnapKind.grid => snapWeekMinutes(minutes),
};

/// Alias: create/retarget = hour floor (раньше был round-to-nearest hour).
int snapWeekCreateMinutes(int minutes) => weekHourFloorMinutes(minutes);

TimeOfDay timeOfDayFromMinutes(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

int eventStartMinutesOfDay(AppEvent event) {
  final parsed = parseAlmanacTime(event.startTime);
  if (parsed != null) return parsed.hour * 60 + parsed.minute;
  final local = event.start.toLocal();
  return local.hour * 60 + local.minute;
}

int eventActualEndMinutesOfDay(AppEvent event) {
  final start = eventStartMinutesOfDay(event);
  final parsed = parseAlmanacTime(event.endTime);
  if (parsed != null) {
    var end = parsed.hour * 60 + parsed.minute;
    if (end <= start) end += 24 * 60;
    return end;
  }
  return start + openEndedEventDuration.inMinutes;
}

int eventDisplayEndMinutesOfDay(AppEvent event) {
  final start = eventStartMinutesOfDay(event);
  if (!eventHasKnownEndTime(event)) {
    return (start + kWeekDefaultTimedDurationMinutes).clamp(0, 24 * 60);
  }
  return eventActualEndMinutesOfDay(
    event,
  ).clamp(start + kWeekTimeSnapMinutes, 24 * 60);
}

int timedEventDurationMinutes(AppEvent event) {
  if (!eventHasKnownEndTime(event)) return openEndedEventDuration.inMinutes;
  return (eventActualEndMinutesOfDay(event) - eventStartMinutesOfDay(event))
      .clamp(kWeekTimeSnapMinutes, 24 * 60);
}

/// Смена, в которую вложить личное событие (по пересечению минут дня).
AppEvent? resolveParentShiftEvent({
  required int startMinutes,
  required int endMinutes,
  required List<AppEvent> dayEvents,
}) {
  AppEvent? best;
  var bestOverlap = 0;
  for (final event in dayEvents) {
    if (!event.isFromWorkSchedule || !event.isTimed) continue;
    final shiftStart = eventStartMinutesOfDay(event);
    final shiftEnd = eventDisplayEndMinutesOfDay(event);
    if (startMinutes >= shiftEnd || endMinutes <= shiftStart) continue;
    if (startMinutes >= shiftStart && startMinutes < shiftEnd) {
      return event;
    }
    final overlapStart = startMinutes > shiftStart ? startMinutes : shiftStart;
    final overlapEnd = endMinutes < shiftEnd ? endMinutes : shiftEnd;
    final overlap = overlapEnd - overlapStart;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = event;
    }
  }
  return best;
}

DateTimeRange buildPersonalEventDateTimeRange({
  required DateTime day,
  required TimeOfDay start,
  TimeOfDay? end,
}) {
  final startDateTime = DateTime(
    day.year,
    day.month,
    day.day,
    start.hour,
    start.minute,
  );
  if (end == null) {
    return DateTimeRange(
      start: startDateTime,
      end: startDateTime.add(openEndedEventDuration),
    );
  }

  var endDateTime = DateTime(
    day.year,
    day.month,
    day.day,
    end.hour,
    end.minute,
  );
  if (!end.isAfter(start)) {
    endDateTime = endDateTime.add(const Duration(days: 1));
  }
  return DateTimeRange(start: startDateTime, end: endDateTime);
}

/// Разбор времени личного события: конец необязателен.
({TimeOfDay start, TimeOfDay? end})? parsePersonalEventTimes({
  required String startRaw,
  required String endRaw,
}) {
  final start = parseAlmanacTime(startRaw);
  if (start == null) return null;

  final endTrimmed = endRaw.trim();
  if (endTrimmed.isEmpty) {
    return (start: start, end: null);
  }

  final end = parseAlmanacTime(endTrimmed);
  if (end == null || !end.isAfter(start)) return null;
  return (start: start, end: end);
}

/// Переносит событие на другой календарный день, сохраняя время суток.
AppEvent shiftEventToCalendarDate(AppEvent event, DateTime targetDate) {
  final day = DateTime(targetDate.year, targetDate.month, targetDate.day);

  if (!event.isTimed) {
    return event.copyWith(
      dateTimeRange: AppEvent.dateOnlyRange(day),
      isUndated: false,
    );
  }

  final start = parseAlmanacTime(event.startTime);

  final end = parseAlmanacTime(event.endTime);
  if (start == null || end == null) {
    if (!eventHasKnownEndTime(event)) {
      final localStart = event.start.toLocal();
      final startDateTime = DateTime(
        day.year,
        day.month,
        day.day,
        localStart.hour,
        localStart.minute,
      );
      return event.copyWith(
        dateTimeRange: DateTimeRange(
          start: startDateTime,
          end: startDateTime.add(openEndedEventDuration),
        ),
        isUndated: false,
      );
    }

    final duration = event.dateTimeRange.duration;
    final localStart = event.start.toLocal();
    final startDateTime = DateTime(
      day.year,
      day.month,
      day.day,
      localStart.hour,
      localStart.minute,
    );
    return event.copyWith(
      dateTimeRange: DateTimeRange(
        start: startDateTime,
        end: startDateTime.add(duration),
      ),
      isUndated: false,
    );
  }

  final startDateTime = DateTime(
    day.year,
    day.month,
    day.day,
    start.hour,
    start.minute,
  );
  var endDateTime = DateTime(
    day.year,
    day.month,
    day.day,
    end.hour,
    end.minute,
  );
  if (!end.isAfter(start)) {
    endDateTime = endDateTime.add(const Duration(days: 1));
  }

  return event.copyWith(
    dateTimeRange: DateTimeRange(start: startDateTime, end: endDateTime),
    isUndated: false,
  );
}

/// Переносит timed-событие на день и новое начало, сохраняя длительность.
AppEvent shiftEventToCalendarDateTime(
  AppEvent event,
  DateTime targetDate,
  TimeOfDay startTime,
) {
  final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
  if (!event.isTimed) {
    return shiftEventToCalendarDate(event, day);
  }

  final newStart = DateTime(
    day.year,
    day.month,
    day.day,
    startTime.hour,
    startTime.minute,
  );

  if (!eventHasKnownEndTime(event)) {
    return event.copyWith(
      dateTimeRange: DateTimeRange(
        start: newStart,
        end: newStart.add(openEndedEventDuration),
      ),
      startTime: formatAlmanacTime(startTime),
      isUndated: false,
    );
  }

  final newEnd = newStart.add(
    Duration(minutes: timedEventDurationMinutes(event)),
  );
  return event.copyWith(
    dateTimeRange: DateTimeRange(start: newStart, end: newEnd),
    startTime: formatAlmanacTime(startTime),
    endTime: formatAlmanacTime(
      TimeOfDay(hour: newEnd.hour, minute: newEnd.minute),
    ),
    isUndated: false,
  );
}

/// Меняет начало и конец timed-события (resize на сетке).
AppEvent resizeTimedEventTimes(
  AppEvent event, {
  required int startMinutes,
  required int endMinutes,
}) {
  final snappedStart = snapWeekMinutes(
    startMinutes,
  ).clamp(0, 24 * 60 - kWeekTimeSnapMinutes);
  final snappedEnd = snapWeekMinutes(
    endMinutes,
  ).clamp(snappedStart + kWeekTimeSnapMinutes, 24 * 60);
  final local = event.start.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final start = day.add(Duration(minutes: snappedStart));
  final end = day.add(Duration(minutes: snappedEnd));
  return event.copyWith(
    dateTimeRange: DateTimeRange(start: start, end: end),
    startTime: formatAlmanacTime(timeOfDayFromMinutes(snappedStart)),
    endTime: snappedEnd >= 24 * 60
        ? formatAlmanacTime(const TimeOfDay(hour: 0, minute: 0))
        : formatAlmanacTime(timeOfDayFromMinutes(snappedEnd)),
  );
}

/// Длительность смены в минутах (с учётом ночных смен через полночь).
int eventWorkDurationMinutes(AppEvent event) {
  final start = parseAlmanacTime(event.startTime);

  final end = parseAlmanacTime(event.endTime);
  if (start == null || end == null) {
    return event.dateTimeRange.duration.inMinutes.abs();
  }

  var minutes = (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
  if (minutes <= 0) minutes += 24 * 60;
  return minutes;
}

/// Регулярные и сверхурочные минуты для события.
({int regularMinutes, int overtimeMinutes}) splitWorkMinutes({
  required AppEvent event,
  required double standardHoursPerShift,
  int breakMinutes = 0,
}) {
  final gross = eventWorkDurationMinutes(event);

  final unpaid = event.unpaidMinutes ?? 0;
  final paid = (gross - breakMinutes - unpaid).clamp(0, gross);

  final standardMinutes = (standardHoursPerShift * 60).round();

  if (event.overtimeMinutes != null) {
    final overtime = event.overtimeMinutes!.clamp(0, paid);
    return (
      regularMinutes: (paid - overtime).clamp(0, paid),
      overtimeMinutes: overtime,
    );
  }

  if (paid <= standardMinutes) {
    return (regularMinutes: paid, overtimeMinutes: 0);
  }
  return (
    regularMinutes: standardMinutes,
    overtimeMinutes: paid - standardMinutes,
  );
}

String formatWorkHours(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (minutes == 0) return '$hours ч';
  return '$hours ч $minutes мин';
}

String formatMoney(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toStringAsFixed(0)} ₽';
  }
  return '${value.toStringAsFixed(2)} ₽';
}

/// Разбор суммы из поля ввода (поддерживает запятую как десятичный разделитель).
double? parseMoneyAmount(String raw) {
  final normalized = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null || value <= 0) return null;
  return value;
}

int _minutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

/// Время срабатывания напоминания по началу события и смещению в минутах.
TimeOfDay? reminderFireTimeFromMinutesBefore({
  required TimeOfDay eventStart,
  required int minutesBefore,
}) {
  if (minutesBefore < 0) return null;

  var fireMinutes = _minutesOfDay(eventStart) - minutesBefore;
  while (fireMinutes < 0) {
    fireMinutes += 24 * 60;
  }
  fireMinutes %= 24 * 60;
  return TimeOfDay(hour: fireMinutes ~/ 60, minute: fireMinutes % 60);
}

/// Смещение в минутах до начала события по времени напоминания.
int minutesBeforeFromReminderFireTime({
  required TimeOfDay eventStart,
  required TimeOfDay reminderTime,
}) {
  final start = _minutesOfDay(eventStart);

  final fire = _minutesOfDay(reminderTime);
  if (fire <= start) return start - fire;
  return start + (24 * 60 - fire);
}

String? reminderFireTimeText({
  required String eventStartTime,
  required int? minutesBefore,
}) {
  if (minutesBefore == null) return null;
  final eventStart = parseAlmanacTime(eventStartTime);
  if (eventStart == null) return null;
  final fireTime = reminderFireTimeFromMinutesBefore(
    eventStart: eventStart,
    minutesBefore: minutesBefore,
  );
  if (fireTime == null) return null;
  return formatAlmanacTime(fireTime);
}

int? minutesBeforeFromReminderFireTimeText({
  required String eventStartTime,
  required String reminderTimeText,
}) {
  final trimmed = reminderTimeText.trim();
  if (trimmed.isEmpty) return null;

  final eventStart = parseAlmanacTime(eventStartTime);

  final reminderTime = parseAlmanacTime(trimmed);
  if (eventStart == null || reminderTime == null) return null;

  final minutes = minutesBeforeFromReminderFireTime(
    eventStart: eventStart,
    reminderTime: reminderTime,
  );
  if (minutes > ReminderPresets.maxMinutesBefore) return null;
  return minutes;
}
