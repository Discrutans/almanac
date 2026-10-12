import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart';
import 'calendar_types.dart';

/// Тестовые события для демонстрации календаря.
final class TestEvents {
  static List<AppEvent> currentYear() {
    return [
      _event(
        id: 'event-1',
        month: 1,
        day: 1,
        startHour: 9,
        title: 'Новый год',
        color: Colors.red,
      ),
      _event(
        id: 'event-2',
        month: 1,
        day: 15,
        startHour: 14,
        title: 'Совещание команды',
        color: Colors.blue,
      ),
      _event(
        id: 'event-3',
        month: 2,
        day: 14,
        startHour: 11,
        title: 'День святого Валентина',
        color: Colors.pink,
      ),
      _event(
        id: 'event-4',
        month: 2,
        day: 28,
        startHour: 18,
        title: 'Выходной',
        color: Colors.green,
      ),
      _event(
        id: 'event-5',
        month: 3,
        day: 8,
        startHour: 10,
        title: 'Международный женский день',
        color: Colors.purple,
      ),
      _event(
        id: 'event-6',
        month: 3,
        day: 20,
        startHour: 16,
        title: 'Программирование',
        color: Colors.indigo,
      ),
      _event(
        id: 'event-7',
        month: 4,
        day: 1,
        startHour: 9,
        title: 'Начало месяца',
        color: Colors.teal,
      ),
      _event(
        id: 'event-8',
        month: 4,
        day: 18,
        startHour: 14,
        title: 'Проверка',
        color: Colors.amber,
      ),
      _event(
        id: 'event-9',
        month: 5,
        day: 9,
        startHour: 11,
        title: 'День Победы',
        color: Colors.red,
      ),
      _event(
        id: 'event-10',
        month: 5,
        day: 25,
        startHour: 15,
        title: 'Командный обед',
        color: Colors.orange,
      ),
      _event(
        id: 'event-11',
        month: 6,
        day: 15,
        startHour: 10,
        title: 'Планирование недели',
        color: Colors.cyan,
      ),
      _event(
        id: 'event-12',
        month: 6,
        day: 18,
        startHour: 15,
        title: 'Встреча по проекту',
        color: Colors.deepPurple,
      ),
      _recurringEvent(
        id: 'event-recurring-standup',
        month: 6,
        day: 2,
        startHour: 9,
        title: 'Ежедневный стендап',
        color: Colors.blueGrey,
        rrule: 'FREQ=DAILY;INTERVAL=1',
      ),
    ];
  }

  static AppEvent _recurringEvent({
    required String id,
    required int month,
    required int day,
    required int startHour,
    required String title,
    required Color color,
    required String rrule,
  }) {
    final event = _event(
      id: id,
      month: month,
      day: day,
      startHour: startHour,
      title: title,
      color: color,
    );
    return event.copyWith(rrule: rrule, seriesId: id);
  }

  static AppEvent _event({
    required String id,
    required int month,
    required int day,
    required int startHour,
    required String title,
    required Color color,
  }) {
    final start = DateTime(DateTime.now().year, month, day, startHour);

    return AppEvent(
      id: id,
      dateTimeRange: DateTimeRange(
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
      title: title,
      startTime: '${start.hour.toString().padLeft(2, '0')}:00',
      endTime: '${(start.hour + 1).toString().padLeft(2, '0')}:00',
      color: color,
      interaction: EventInteraction.allowNone(),
    );
  }
}
