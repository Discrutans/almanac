import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Hold-to-move recognizer for the timed viewport layer.
class WeekHoldMoveRecognizer extends OneSequenceGestureRecognizer {
  WeekHoldMoveRecognizer({
    super.debugOwner,
    required this.delay,
    required this.allowPointer,
    this.resolveDelay,
  });

  Duration delay;
  Duration Function()? resolveDelay;
  bool Function(int pointer) allowPointer;

  void Function(Offset origin)? onHoldAccepted;
  VoidCallback? onHoldRejected;
  void Function(PointerMoveEvent event)? onPointerMove;
  VoidCallback? onPointerUp;
  VoidCallback? onPointerCancel;

  Timer? _holdTimer;
  int? _pointer;
  Offset? _initialPosition;
  var _accepted = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) {
      resolve(GestureDisposition.rejected);
      return;
    }
    if (!allowPointer(event.pointer)) {
      resolve(GestureDisposition.rejected);
      return;
    }
    startTrackingPointer(event.pointer, event.transform);
    _pointer = event.pointer;
    _initialPosition = event.position;
    _holdTimer?.cancel();
    final holdDelay = resolveDelay?.call() ?? delay;
    _holdTimer = Timer(holdDelay, _onHoldElapsed);
  }

  void _onHoldElapsed() {
    if (_pointer == null) return;
    _accepted = true;
    resolve(GestureDisposition.accepted);
    final origin = _initialPosition;
    if (origin != null) {
      onHoldAccepted?.call(origin);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_accepted && event is PointerMoveEvent) {
      final origin = _initialPosition;
      if (origin != null) {
        final slop = computeHitSlop(event.kind, gestureSettings);
        if ((event.position - origin).distance > slop) {
          _holdTimer?.cancel();
          if (!_accepted) {
            resolve(GestureDisposition.rejected);
            onHoldRejected?.call();
          }
          return;
        }
      }
    }
    if (_accepted && event is PointerMoveEvent) {
      onPointerMove?.call(event);
    }
    if (event is PointerUpEvent) {
      if (_accepted) {
        onPointerUp?.call();
      }
      stopTrackingPointer(event.pointer);
      _reset();
    }
    if (event is PointerCancelEvent) {
      if (_accepted) {
        onPointerCancel?.call();
      } else {
        onHoldRejected?.call();
      }
      stopTrackingPointer(event.pointer);
      _reset();
    }
  }

  void _reset() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointer = null;
    _initialPosition = null;
    _accepted = false;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _holdTimer?.cancel();
    _reset();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'week_hold_move';
}
