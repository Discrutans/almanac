import 'package:flutter/material.dart';

import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import 'week_drop_hit_test.dart';
import 'week_grid_slot.dart';
import 'week_move_types.dart';

/// Single owner of week-grid move preview + commit (carousel and wide).
class WeekMoveController extends ChangeNotifier {
  WeekMoveController({required this.resolveTarget});

  /// Layout-specific hit-test (carousel timed box vs wide timed viewport).
  WeekDropTarget? Function(Offset global) resolveTarget;

  bool active = false;
  Offset? lastGlobal;
  WeekMovePayload? payload;
  WeekDropPreview? preview;
  DateTime? highlightDate;

  WeekMoveCandidate? _pendingCandidate;
  int? _pendingPointer;
  Offset? _pendingGlobal;
  int _grabOffsetMinutes = 0;

  int? get pendingPointer => _pendingPointer;

  Duration? get pendingDelay => _pendingCandidate?.delay;

  Offset? get pendingGlobal => _pendingGlobal;

  AppEvent? get draggingEvent {
    final p = payload;
    return p is WeekMoveEventPayload ? p.event : null;
  }

  WeekGridSlot? get draggingSlot {
    final p = payload;
    return p is WeekMoveSlotPayload ? p.slot : null;
  }

  bool get hasPendingCandidate => _pendingCandidate != null;

  /// Register a move candidate for [pointer] (tile / armed / slot body).
  void offer({
    required int pointer,
    required Offset global,
    required WeekMoveCandidate candidate,
  }) {
    if (active) return;
    _pendingPointer = pointer;
    _pendingGlobal = global;
    _pendingCandidate = candidate;
  }

  /// Consumed by the timed-layer hold recognizer when the hold wins.
  WeekMoveCandidate? takeCandidate(int pointer) {
    if (_pendingPointer != pointer) return null;
    final candidate = _pendingCandidate;
    _pendingCandidate = null;
    _pendingPointer = null;
    _pendingGlobal = null;
    return candidate;
  }

  void clearOffer(int pointer) {
    if (_pendingPointer != pointer) return;
    _pendingCandidate = null;
    _pendingPointer = null;
    _pendingGlobal = null;
  }

  void start(WeekMoveCandidate candidate, {required Offset global}) {
    candidate.onBeforeStart?.call();
    active = true;
    payload = candidate.payload;
    lastGlobal = null;
    preview = null;
    highlightDate = null;
    _grabOffsetMinutes = _computeGrabOffset(global, candidate.payload);
    notifyListeners();
    pointerMove(global);
  }

  int _computeGrabOffset(Offset global, WeekMovePayload payload) {
    final target = resolveTarget(global);
    final rawMinutes = target?.minutesOfDay;
    if (rawMinutes == null || target!.isAllDayHost) return 0;

    return switch (payload) {
      WeekMoveEventPayload(:final event) when event.isTimed => () {
          final start = eventStartMinutesOfDay(event);
          final end = eventDisplayEndMinutesOfDay(event);
          final duration = (end - start).clamp(
            kWeekTimeSnapMinutes,
            24 * 60,
          );
          final snapped = snapWeekMinutes(rawMinutes);
          return (snapped - start).clamp(0, duration - kWeekTimeSnapMinutes);
        }(),
      WeekMoveSlotPayload(:final slot) => () {
          final duration = (slot.endMinutes - slot.startMinutes).clamp(
            kWeekTimeSnapMinutes,
            24 * 60,
          );
          final snapped = snapWeekMinutes(rawMinutes);
          return (snapped - slot.startMinutes)
              .clamp(0, duration - kWeekTimeSnapMinutes);
        }(),
      _ => 0,
    };
  }

  WeekDropTarget? _targetWithGrab(WeekDropTarget? target) {
    if (target == null || target.minutesOfDay == null || target.isAllDayHost) {
      return target;
    }
    final raw = target.minutesOfDay!;
    final start = snapWeekMinutes(raw - _grabOffsetMinutes).clamp(
      0,
      24 * 60 - kWeekTimeSnapMinutes,
    );
    return target.copyWith(minutesOfDay: start);
  }

  void pointerMove(Offset global) {
    if (!active) return;
    lastGlobal = global;
    _refreshFromPointer(global);
  }

  void update(Offset global) => pointerMove(global);

  void refreshAfterLayout() {
    final global = lastGlobal;
    if (!active || global == null) return;
    _refreshFromPointer(global);
  }

  WeekMoveResult commit() {
    if (!active) return const WeekMoveCancelled();
    final global = lastGlobal;
    final movePayload = payload;
    if (global == null || movePayload == null) {
      return const WeekMoveRejected();
    }

    final target = _targetWithGrab(resolveTarget(global));
    if (target == null) {
      return const WeekMoveRejected();
    }

    return switch (movePayload) {
      WeekMoveEventPayload(:final event) => _commitEvent(event, target),
      WeekMoveSlotPayload(:final slot) => _commitSlot(slot, target),
    };
  }

  WeekMoveResult _commitEvent(AppEvent event, WeekDropTarget target) {
    if (_isUnchangedEventDrop(event, target)) {
      return const WeekMoveUnchanged();
    }
    final resolved = weekResolveDropCommit(event: event, target: target);
    if (!resolved.accepted) {
      if (_isUnchangedEventDrop(event, target)) {
        return const WeekMoveUnchanged();
      }
      return const WeekMoveRejected();
    }
    return WeekMoveEventMoved(
      event: event,
      date: resolved.date,
      startTime: resolved.startTime,
    );
  }

  bool _isUnchangedEventDrop(AppEvent event, WeekDropTarget target) {
    if (!event.isTimed ||
        target.isAllDayHost ||
        target.minutesOfDay == null) {
      return false;
    }
    if (!event.isOnDate(target.date)) return false;
    return target.minutesOfDay == eventStartMinutesOfDay(event);
  }

  WeekMoveResult _commitSlot(WeekGridSlot slot, WeekDropTarget target) {
    if (target.isAllDayHost || target.minutesOfDay == null) {
      return const WeekMoveRejected();
    }
    final moved = slot.movedTo(
      date: target.date,
      startMinutes: target.minutesOfDay!,
    );
    if (moved.date == slot.date &&
        moved.startMinutes == slot.startMinutes &&
        moved.endMinutes == slot.endMinutes) {
      return const WeekMoveUnchanged();
    }
    final resolved = weekResolveSlotDrop(slot: slot, target: target);
    if (!resolved.accepted || resolved.slot == null) {
      return const WeekMoveRejected();
    }
    return WeekMoveSlotMoved(resolved.slot!);
  }

  void finish() {
    if (!active &&
        payload == null &&
        preview == null &&
        _pendingCandidate == null) {
      return;
    }
    active = false;
    lastGlobal = null;
    payload = null;
    preview = null;
    highlightDate = null;
    _grabOffsetMinutes = 0;
    _pendingCandidate = null;
    _pendingPointer = null;
    _pendingGlobal = null;
    notifyListeners();
  }

  void cancel() {
    finish();
  }

  void _refreshFromPointer(Offset global) {
    final target = _targetWithGrab(resolveTarget(global));
    final nextPreview = weekDropPreviewForTarget(
      target: target,
      dragging: draggingEvent,
      draggingSlot: draggingSlot,
    );
    _setVisual(preview: nextPreview, highlight: target?.date);
  }

  void _setVisual({
    required WeekDropPreview? preview,
    required DateTime? highlight,
  }) {
    final samePreview =
        preview == this.preview ||
        (preview != null &&
            this.preview != null &&
            preview.isOnDate(this.preview!.date) &&
            preview.startMinutes == this.preview!.startMinutes &&
            preview.endMinutes == this.preview!.endMinutes);
    final sameHighlight =
        highlight == null && highlightDate == null ||
        (highlight != null &&
            highlightDate != null &&
            isSameCalendarDay(highlight, highlightDate!));
    if (samePreview && sameHighlight) return;
    this.preview = preview;
    highlightDate = highlight;
    notifyListeners();
  }
}
