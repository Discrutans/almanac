import '../../calendar_types.dart';
import 'week_drag_policy.dart';
import 'week_grid_slot.dart';
import 'week_move_types.dart';

WeekMoveCandidate? weekMoveCandidateForEvent({
  required AppEvent event,
  required WeekDragSession session,
}) {
  if (!weekEventMayDrop(event)) return null;
  final lockedByOther = session.isLockedByOther(event.id);
  if (weekDragIsForeverLocked(event, lockedByOther: lockedByOther)) {
    return null;
  }
  final armed = session.isArmed(event.id);
  final immediate = weekDragIsImmediate(event, lockedByOther: lockedByOther);
  final canUnlock = weekDragCanUnlock(event, lockedByOther: lockedByOther);
  if (!immediate && !(canUnlock && armed) && !canUnlock) {
    return null;
  }
  return WeekMoveCandidate(
    payload: WeekMoveEventPayload(event),
    delay: weekMoveHoldDelay(
      event,
      armed: armed,
      lockedByOther: lockedByOther,
    ),
    onBeforeStart: () {
      if (!armed && canUnlock) {
        session.onArmed?.call(event);
      }
    },
  );
}

WeekMoveCandidate weekMoveCandidateForSlot(WeekGridSlot slot) {
  return WeekMoveCandidate(
    payload: WeekMoveSlotPayload(slot),
    delay: weekDragHoldImmediate,
  );
}

WeekMoveCandidate weekMoveCandidateForArmedEvent(AppEvent event) {
  return WeekMoveCandidate(
    payload: WeekMoveEventPayload(event),
    delay: weekDragDelayArmed,
  );
}

bool weekMoveShouldShakeOnSlop({
  required AppEvent event,
  required WeekDragSession session,
}) {
  final lockedByOther = session.isLockedByOther(event.id);
  return weekEventShowsLock(
    event,
    lockedByOther: lockedByOther,
    armed: session.isArmed(event.id),
  );
}
