import 'package:flutter/material.dart';

import '../../../data/events/event_overlap.dart';
import '../../calendar_entry_capabilities.dart';
import '../../calendar_types.dart';
import '../../event_time_utils.dart';

/// Единые задержки long-press / drag на недельной сетке.
const Duration weekDragDelayImmediate = Duration(milliseconds: 380);
const Duration weekDragDelayArmed = Duration(milliseconds: 180);
const Duration weekDragDelayUnlock = Duration(milliseconds: 1000);
const Duration weekDragDelayAllDay = Duration(milliseconds: 140);
const Duration weekDragHoldImmediate = Duration(milliseconds: 280);
const Duration weekDragHoldAllDay = Duration(milliseconds: 120);

/// Hold delay before the timed-layer recognizer starts a move.
Duration weekMoveHoldDelay(
  AppEvent event, {
  required bool armed,
  required bool lockedByOther,
}) {
  if (_isAllDayKind(event) && weekDragIsImmediate(event, lockedByOther: lockedByOther)) {
    return weekDragDelayAllDay;
  }
  if (weekDragIsImmediate(event, lockedByOther: lockedByOther)) {
    return weekDragDelayImmediate;
  }
  if (armed) return weekDragDelayArmed;
  return weekDragDelayUnlock;
}

bool _isAllDayKind(AppEvent event) => !event.isTimed;

/// Состояние разблокировки и чужих lock на недельной сетке.
@immutable
class WeekDragSession {
  const WeekDragSession({
    this.armedEventId,
    this.lockedByOtherIds = const {},
    this.onArmed,
    this.onBackgroundTap,
  });

  static const empty = WeekDragSession();

  final String? armedEventId;
  final Set<String> lockedByOtherIds;
  final ValueChanged<AppEvent>? onArmed;
  final VoidCallback? onBackgroundTap;

  bool isArmed(String eventId) => armedEventId == eventId;

  bool isLockedByOther(String eventId) => lockedByOtherIds.contains(eventId);
}

/// Сразу тащится (личное без серии, цель накопления).
bool weekDragIsImmediate(AppEvent event, {required bool lockedByOther}) {
  if (lockedByOther) return false;
  return event.capabilities.weekDragImmediate;
}

/// Замок можно снять long-press.
bool weekDragCanUnlock(AppEvent event, {required bool lockedByOther}) {
  if (lockedByOther) return false;
  return event.capabilities.canUnlockForWeekMove;
}

bool weekDragIsForeverLocked(AppEvent event, {required bool lockedByOther}) {
  if (lockedByOther) return true;
  return !event.capabilities.canMoveOnWeekGrid;
}

bool weekEventShowsLock(
  AppEvent event, {
  required bool lockedByOther,
  required bool armed,
}) {
  if (armed) return false;
  if (lockedByOther) return true;
  return event.capabilities.showsWeekLock;
}

/// Можно начать/продолжить drag: immediate или уже armed unlockable.
bool weekEventCanDragNow(
  AppEvent event, {
  required bool lockedByOther,
  required bool armed,
}) {
  if (weekDragIsImmediate(event, lockedByOther: lockedByOther)) return true;
  if (weekDragCanUnlock(event, lockedByOther: lockedByOther) && armed) {
    return true;
  }
  return false;
}

/// Событие, которое сетка вообще может перенести (после unlock).
bool weekEventMayDrop(AppEvent event) => event.capabilities.canMoveOnWeekGrid;

bool weekEventCanResizeNow(
  AppEvent event, {
  required bool lockedByOther,
  required bool armed,
}) {
  return event.isTimed &&
      weekEventCanDragNow(
        event,
        lockedByOther: lockedByOther,
        armed: armed,
      );
}

AppEvent previewWeekMove(
  AppEvent event,
  DateTime targetDate,
  TimeOfDay? startTime,
) {
  if (startTime != null && event.isTimed) {
    return shiftEventToCalendarDateTime(event, targetDate, startTime);
  }
  return shiftEventToCalendarDate(event, targetDate);
}

bool weekDropConflicts({
  required AppEvent event,
  required DateTime targetDate,
  TimeOfDay? startTime,
  required List<AppEvent> existingEvents,
}) {
  if (!event.isTimed) return false;
  final moved = previewWeekMove(event, targetDate, startTime);
  return hasEventConflict(
    candidateStart: moved.start,
    candidateEnd: moved.end,
    existingEvents: existingEvents,
    excludeEventId: event.id,
    excludeSeriesId: event.seriesId ?? event.id,
  );
}
