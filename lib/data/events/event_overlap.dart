import '../../calendar/calendar_types.dart';
import 'recurrence_engine.dart';

DateTime _local(DateTime dt) => dt.toLocal();

DateTime _dayStart(DateTime dt) {
  final local = _local(dt);
  return DateTime(local.year, local.month, local.day);
}

/// Проверяет пересечение двух временных диапазонов (полуоткрытый интервал).
bool timeRangesOverlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
}

/// Проверяет, попадают ли два момента на один календарный день (локальное время).
bool eventsOnSameDay(DateTime a, DateTime b) {
  final la = _local(a);

  final lb = _local(b);
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Возвращает true, если [candidateStart]/[candidateEnd] конфликтует с событиями.
///
/// Для повторяющихся событий разворачивает вхождения по всем дням интервала
/// кандидата (overnight / multi-day).
bool hasEventConflict({
  required DateTime candidateStart,
  required DateTime candidateEnd,
  required List<AppEvent> existingEvents,
  String? excludeEventId,
  String? excludeSeriesId,
  bool ignoreScheduleEvents = true,
}) {
  return findConflictingEvents(
    candidateStart: candidateStart,
    candidateEnd: candidateEnd,
    existingEvents: existingEvents,
    excludeEventId: excludeEventId,
    excludeSeriesId: excludeSeriesId,
    ignoreScheduleEvents: ignoreScheduleEvents,
  ).isNotEmpty;
}

/// Возвращает список событий, с которыми пересекается кандидат.
List<AppEvent> findConflictingEvents({
  required DateTime candidateStart,
  required DateTime candidateEnd,
  required List<AppEvent> existingEvents,
  String? excludeEventId,
  String? excludeSeriesId,
  bool ignoreScheduleEvents = true,
}) {
  final localStart = _local(candidateStart);
  final localEnd = _local(candidateEnd);

  // Half-open [start, end): expand every calendar day the candidate touches.
  final rangeStart = _dayStart(localStart);
  var rangeEndExclusive = _dayStart(localEnd);
  if (localEnd.isAfter(rangeEndExclusive)) {
    // End has a time on that day → include the day.
    rangeEndExclusive = rangeEndExclusive.add(const Duration(days: 1));
  }
  if (!rangeEndExclusive.isAfter(rangeStart)) {
    rangeEndExclusive = rangeStart.add(const Duration(days: 1));
  }

  final expanded = RecurrenceEngine.expandAll(
    existingEvents,
    rangeStart: rangeStart,
    rangeEnd: rangeEndExclusive,
  );

  final conflicts = <AppEvent>[];
  final seenIds = <String>{};

  for (final event in expanded) {
    if (excludeEventId != null && event.id == excludeEventId) continue;
    if (excludeSeriesId != null && event.seriesId == excludeSeriesId) continue;
    if (ignoreScheduleEvents && event.isFromWorkSchedule) continue;

    if (!timeRangesOverlap(
      localStart,
      localEnd,
      event.start,
      event.end,
    )) {
      continue;
    }

    if (seenIds.add(event.id)) {
      conflicts.add(event);
    }
  }

  return conflicts;
}

/// Конфликты с личными событиями при редактировании смены/расписания.
///
/// Исключает редактируемое вхождение и всю серию расписания, чтобы
/// сохранение сверхурочных и заметок не блокировалось «самим собой».
List<AppEvent> findScheduleEditConflicts({
  required DateTime candidateStart,
  required DateTime candidateEnd,
  required List<AppEvent> existingEvents,
  required AppEvent editingEvent,
}) {
  final scheduleId = editingEvent.workScheduleId;
  final excludeSeriesId = scheduleId != null
      ? 'schedule-$scheduleId'
      : editingEvent.seriesId;

  return findConflictingEvents(
    candidateStart: candidateStart,
    candidateEnd: candidateEnd,
    existingEvents: existingEvents,
    excludeEventId: editingEvent.id,
    excludeSeriesId: excludeSeriesId,
  ).where((event) => !event.isFromWorkSchedule).toList();
}
