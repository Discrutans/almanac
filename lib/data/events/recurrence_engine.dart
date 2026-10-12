import 'package:flutter/material.dart';
import 'package:rrule/rrule.dart';
import '../../calendar/calendar_types.dart';
import 'recurrence_exdate.dart';

/// Предустановленные шаблоны повторения для UI.
enum RecurrencePreset { none, daily, weekly, monthly, custom }

/// Область сохранения при редактировании вхождения серии.
enum RecurrenceEditScope { thisOccurrenceOnly, wholeSeries }

extension RecurrencePresetX on RecurrencePreset {
  /// RFC 5545 RRULE-строка (без префикса RRULE:).
  String? get rruleString => switch (this) {
    RecurrencePreset.none => null,
    RecurrencePreset.daily => 'FREQ=DAILY;INTERVAL=1',
    RecurrencePreset.weekly => 'FREQ=WEEKLY;INTERVAL=1',
    RecurrencePreset.monthly => 'FREQ=MONTHLY;INTERVAL=1',
    RecurrencePreset.custom => null,
  };

  static RecurrencePreset fromRrule(String? rrule) {
    final base = RecurrenceExdateCodec.baseRrule(rrule);
    if (base == null || base.isEmpty) return RecurrencePreset.none;
    if (base.contains('FREQ=DAILY')) return RecurrencePreset.daily;
    if (base.contains('FREQ=WEEKLY')) return RecurrencePreset.weekly;
    if (base.contains('FREQ=MONTHLY')) return RecurrencePreset.monthly;
    return RecurrencePreset.custom;
  }
}

/// Разворачивает повторяющиеся события во вхождения для заданного диапазона.
final class RecurrenceEngine {
  RecurrenceEngine._();

  static final _codec = RecurrenceRuleStringCodec();

  /// Разворачивает список событий (включая повторяющиеся) в плоский список вхождений.
  static List<AppEvent> expandAll(
    List<AppEvent> events, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final result = <AppEvent>[];

    for (final event in events) {
      if (event.hasRecurrence) {
        result.addAll(
          expandEvent(event, rangeStart: rangeStart, rangeEnd: rangeEnd),
        );
      } else {
        if (_eventIntersectsRange(event, rangeStart, rangeEnd)) {
          result.add(event);
        }
      }
    }

    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  /// Разворачивает одно событие во вхождения в диапазоне [rangeStart, rangeEnd).
  static List<AppEvent> expandEvent(
    AppEvent event, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (!event.hasRecurrence) {
      return _eventIntersectsRange(event, rangeStart, rangeEnd)
          ? [event]
          : const [];
    }

    final baseRrule = RecurrenceExdateCodec.baseRrule(event.rrule);
    if (baseRrule == null || baseRrule.isEmpty) return [event];

    final rule = _parseRule(baseRrule);
    if (rule == null) return [event];

    final local = event.start.toLocal();
    final dtStart = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );

    final instances = rule
        .getInstances(start: dtStart)
        .map(_fromRruleInstance)
        .takeWhile((local) {
          if (!local.isBefore(rangeEnd)) return false;
          if (event.recurrenceUntil != null &&
              local.isAfter(event.recurrenceUntil!)) {
            return false;
          }
          return true;
        })
        .where((local) => !local.isBefore(rangeStart))
        .where((local) => !event.excludesRecurrenceDay(local));

    final duration = event.dateTimeRange.duration;

    return instances.map((localStart) {
      final localEnd = localStart.add(duration);

      return event.copyWith(
        id: '${event.seriesId ?? event.id}-${localStart.millisecondsSinceEpoch}',
        dateTimeRange: DateTimeRange(start: localStart, end: localEnd),
        isRecurrenceOccurrence: true,
      );
    }).toList();
  }

  static RecurrenceRule? _parseRule(String rruleString) {
    try {
      final normalized = rruleString.startsWith('RRULE:')
          ? rruleString
          : 'RRULE:$rruleString';
      return _codec.decode(normalized);
    } catch (_) {
      return null;
    }
  }

  static bool _eventIntersectsRange(
    AppEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return event.start.isBefore(rangeEnd) && event.end.isAfter(rangeStart);
  }

  /// rrule возвращает UTC-метки с «настенным» временем — не конвертируем через toLocal().
  static DateTime _fromRruleInstance(DateTime instance) {
    return DateTime(
      instance.year,
      instance.month,
      instance.day,
      instance.hour,
      instance.minute,
      instance.second,
    );
  }
}
