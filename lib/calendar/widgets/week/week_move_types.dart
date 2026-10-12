import 'package:flutter/material.dart';

import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import 'week_grid_slot.dart';

/// Payload being moved on the week grid.
sealed class WeekMovePayload {
  const WeekMovePayload();

  /// Minutes to pin the viewport when hideEmpty expands for this drag.
  int? get pinMinutes;
}

final class WeekMoveEventPayload extends WeekMovePayload {
  const WeekMoveEventPayload(this.event);

  final AppEvent event;

  @override
  int? get pinMinutes =>
      event.isTimed ? eventStartMinutesOfDay(event) : null;
}

final class WeekMoveSlotPayload extends WeekMovePayload {
  const WeekMoveSlotPayload(this.slot);

  final WeekGridSlot slot;

  @override
  int? get pinMinutes => slot.startMinutes;
}

/// Offered on pointer down before the timed-layer hold recognizer wins.
final class WeekMoveCandidate {
  const WeekMoveCandidate({
    required this.payload,
    required this.delay,
    this.onBeforeStart,
  });

  final WeekMovePayload payload;
  final Duration delay;
  final VoidCallback? onBeforeStart;
}

/// Outcome of [WeekMoveController.commit] / [WeekMoveController.cancel].
sealed class WeekMoveResult {
  const WeekMoveResult();
}

final class WeekMoveEventMoved extends WeekMoveResult {
  const WeekMoveEventMoved({
    required this.event,
    required this.date,
    this.startTime,
  });

  final AppEvent event;
  final DateTime date;
  final TimeOfDay? startTime;
}

final class WeekMoveSlotMoved extends WeekMoveResult {
  const WeekMoveSlotMoved(this.slot);

  final WeekGridSlot slot;
}

final class WeekMoveUnchanged extends WeekMoveResult {
  const WeekMoveUnchanged();
}

final class WeekMoveRejected extends WeekMoveResult {
  const WeekMoveRejected();
}

final class WeekMoveCancelled extends WeekMoveResult {
  const WeekMoveCancelled();
}
