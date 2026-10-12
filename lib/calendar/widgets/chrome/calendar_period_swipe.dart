import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Горизонтальный свайп для листания месяца / недели / года.
///
/// Срабатывает только когда горизонтальное движение явно доминирует.
class CalendarPeriodSwipeDetector extends StatefulWidget {
  const CalendarPeriodSwipeDetector({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
    this.enabled = true,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;
  final bool enabled;

  @override
  State<CalendarPeriodSwipeDetector> createState() =>
      _CalendarPeriodSwipeDetectorState();
}

class _CalendarPeriodSwipeDetectorState
    extends State<CalendarPeriodSwipeDetector> {
  double _dragDeltaX = 0;
  double _dragDeltaY = 0;
  bool? _horizontalLocked;

  static const _distanceThreshold = 56.0;
  static const _velocityThreshold = 320.0;
  static const _axisLockRatio = 2.0;
  static const _axisDecisionSlop = 10.0;

  void _resetDrag() {
    _dragDeltaX = 0;
    _dragDeltaY = 0;
    _horizontalLocked = null;
  }

  void _updateAxisLock() {
    if (_horizontalLocked != null) return;

    final absX = _dragDeltaX.abs();
    final absY = _dragDeltaY.abs();
    if (absX < _axisDecisionSlop && absY < _axisDecisionSlop) return;

    if (absY > absX * _axisLockRatio) {
      _horizontalLocked = false;
    } else if (absX > absY * _axisLockRatio) {
      _horizontalLocked = true;
    }
  }

  bool _isHorizontalDominant({required double velocityX}) {
    final absX = _dragDeltaX.abs();
    final absY = _dragDeltaY.abs();
    if (_horizontalLocked == false) return false;
    if (_horizontalLocked == true) return true;
    if (velocityX.abs() >= _velocityThreshold) {
      return velocityX.abs() > absY * _axisLockRatio;
    }
    if (absX < _axisDecisionSlop && absY > absX) return false;
    if (absY > absX * _axisLockRatio) return false;
    return absX >= absY * _axisLockRatio;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              () => PanGestureRecognizer(),
              (PanGestureRecognizer instance) {
                instance.onStart = (_) => _resetDrag();
                instance.onUpdate = (details) {
                  _dragDeltaX += details.delta.dx;
                  _dragDeltaY += details.delta.dy.abs();
                  _updateAxisLock();
                };
                instance.onEnd = (details) {
                  final velocityX = details.velocity.pixelsPerSecond.dx;
                  if (!_isHorizontalDominant(velocityX: velocityX)) {
                    _resetDrag();
                    return;
                  }

                  if (_dragDeltaX <= -_distanceThreshold ||
                      velocityX < -_velocityThreshold) {
                    widget.onNext();
                  } else if (_dragDeltaX >= _distanceThreshold ||
                      velocityX > _velocityThreshold) {
                    widget.onPrevious();
                  }
                  _resetDrag();
                };
                instance.onCancel = _resetDrag;
              },
            ),
      },
      child: widget.child,
    );
  }
}
