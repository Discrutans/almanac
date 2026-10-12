import '../../calendar_types.dart';
import '../../event_time_utils.dart';

const double kWeekLaneGap = 12;

/// Порядок безвременных карточек в шапке дня.
const List<CalendarEntryKind> kWeekAllDayKindOrder = [
  CalendarEntryKind.checklist,
  CalendarEntryKind.savingsGoal,
  CalendarEntryKind.note,
];

int weekEventStartMinutes(AppEvent event) => eventStartMinutesOfDay(event);

bool isWeekAllDayEvent(AppEvent event) => !event.isTimed;

List<AppEvent> weekAllDayEvents(List<AppEvent> events) => [
  for (final event in events)
    if (isWeekAllDayEvent(event)) event,
];

List<AppEvent> weekTimedEventsAt(List<AppEvent> events, int startMinutes) => [
  for (final event in events)
    if (event.isTimed && weekEventStartMinutes(event) == startMinutes) event,
];

int _allDayKindOrder(CalendarEntryKind kind) {
  final index = kWeekAllDayKindOrder.indexOf(kind);
  return index < 0 ? kWeekAllDayKindOrder.length : index;
}

/// Колонка без сетки: чек-листы и заметки сверху, затем события по времени.
List<AppEvent> sortWeekColumnEvents(List<AppEvent> events) {
  final sorted = List<AppEvent>.from(events);
  sorted.sort((a, b) {
    final aAllDay = isWeekAllDayEvent(a);
    final bAllDay = isWeekAllDayEvent(b);
    if (aAllDay != bAllDay) return aAllDay ? -1 : 1;
    if (aAllDay) {
      final kindCmp = _allDayKindOrder(
        a.kind,
      ).compareTo(_allDayKindOrder(b.kind));
      if (kindCmp != 0) return kindCmp;
      return a.start.compareTo(b.start);
    }
    final timeCmp = weekEventStartMinutes(
      a,
    ).compareTo(weekEventStartMinutes(b));
    if (timeCmp != 0) return timeCmp;
    return a.start.compareTo(b.start);
  });
  return sorted;
}

/// Оценка высоты карточки, чтобы одинаковые слоты совпали по всем дням.
double estimateWeekTileHeight(AppEvent event) {
  var height = 16.0;
  if (event.isTimed) height += 18;
  height += 22;
  switch (event.kind) {
    case CalendarEntryKind.note:
      height += 48;
    case CalendarEntryKind.checklist:
      height += 22;
    case CalendarEntryKind.savingsGoal:
      height += 20;
    case CalendarEntryKind.event:
      height += 16;
  }
  if (event.hasRecurrence ||
      event.reminderMinutesBefore != null ||
      (event.incomeAmount != null && event.incomeAmount! > 0)) {
    height += 18;
  }
  if (event.entrySource.isScheduleRelated) height += 36;
  if (event.hasPomodoro) height += 108;
  return height;
}

double _stackHeight(List<AppEvent> events) {
  if (events.isEmpty) return 0;
  var height = 0.0;
  for (var i = 0; i < events.length; i++) {
    if (i > 0) height += kWeekLaneGap;
    height += estimateWeekTileHeight(events[i]);
  }
  return height;
}

class WeekAllDayLane {
  const WeekAllDayLane({
    required this.kind,
    required this.minHeight,
    required this.expands,
  });

  final CalendarEntryKind kind;
  final double minHeight;
  final bool expands;
}

class WeekTimedLane {
  const WeekTimedLane({required this.startMinutes, required this.height});

  final int startMinutes;
  final double height;
}

/// Общая сетка колонок недели: безвременные слоты сверху, затем время.
/// Historical list layout; live UI uses [WeekHourAxis] + [WeekHourEventTile].
@Deprecated('Historical list layout; live UI uses WeekHourAxis')
class WeekTimelineBlueprint {
  const WeekTimelineBlueprint({
    required this.allDayLanes,
    required this.timedLanes,
  });

  final List<WeekAllDayLane> allDayLanes;
  final List<WeekTimedLane> timedLanes;

  bool get hasAllDayBand => allDayLanes.isNotEmpty;

  double get allDayMinHeight {
    if (allDayLanes.isEmpty) return 0;
    var height = 0.0;
    for (var i = 0; i < allDayLanes.length; i++) {
      if (i > 0) height += kWeekLaneGap;
      height += allDayLanes[i].minHeight;
    }
    return height;
  }

  double get timedHeight {
    if (timedLanes.isEmpty) return 0;
    var height = 0.0;
    for (var i = 0; i < timedLanes.length; i++) {
      if (i > 0) height += kWeekLaneGap;
      height += timedLanes[i].height;
    }
    return height;
  }
}

@Deprecated('Historical list layout; live UI uses WeekHourAxis')
WeekTimelineBlueprint buildWeekTimelineBlueprint(
  Iterable<List<AppEvent>> dayEvents,
) {
  final days = [for (final events in dayEvents) events];
  final allDayLanes = <WeekAllDayLane>[];
  for (final kind in kWeekAllDayKindOrder) {
    var present = false;
    var minHeight = 0.0;
    for (final events in days) {
      final ofKind = [
        for (final event in weekAllDayEvents(events))
          if (event.kind == kind) event,
      ];
      if (ofKind.isEmpty) continue;
      present = true;
      final stacked = _stackHeight(ofKind);
      if (stacked > minHeight) minHeight = stacked;
    }
    if (!present) continue;
    allDayLanes.add(
      WeekAllDayLane(
        kind: kind,
        minHeight: minHeight,
        expands: kind == CalendarEntryKind.note,
      ),
    );
  }

  final starts = <int>{};
  for (final events in days) {
    for (final event in events) {
      if (event.isTimed) starts.add(weekEventStartMinutes(event));
    }
  }
  final orderedStarts = starts.toList()..sort();
  final timedLanes = <WeekTimedLane>[
    for (final start in orderedStarts)
      WeekTimedLane(
        startMinutes: start,
        height: [
          for (final events in days)
            _stackHeight(weekTimedEventsAt(events, start)),
        ].fold<double>(48, (max, height) => height > max ? height : max),
      ),
  ];

  return WeekTimelineBlueprint(
    allDayLanes: allDayLanes,
    timedLanes: timedLanes,
  );
}

@Deprecated('Historical list layout; live UI uses WeekHourAxis')
double weekAllDayBandHeight({
  required WeekTimelineBlueprint blueprint,
  required double viewportHeight,
}) {
  if (!blueprint.hasAllDayBand) return 0;
  final between = blueprint.timedLanes.isEmpty ? 0.0 : kWeekLaneGap;
  final leftover = viewportHeight - blueprint.timedHeight - between;
  if (leftover > blueprint.allDayMinHeight) return leftover;
  return blueprint.allDayMinHeight;
}
