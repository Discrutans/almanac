import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'week_hour_axis.dart';

/// Viewport pin = контракт [hideEmptyWeekHours] при смене геометрии оси
/// (expand 24h ↔ collapse) от user gesture: drag / resize / pinch.
///
/// Держит выбранные минуты на том же [viewportY], чтобы сетка не «улетала»
/// от области события или настроенного часа.
@immutable
class WeekAxisViewportPin {
  const WeekAxisViewportPin({
    required this.pinMinutes,
    required this.viewportY,
  });

  final int pinMinutes;
  final double viewportY;

  /// Capture pin on the **current** (usually collapsed) axis before expand.
  factory WeekAxisViewportPin.capture({
    required WeekHourAxis axis,
    required double scrollOffset,
    int? pinMinutes,
    double bottomAlignPad = 0,
    double topDockHeight = 0,
  }) {
    final pin = pinMinutes ??
        weekAxisFallbackPinMinutes(axis, scrollOffset);
    return WeekAxisViewportPin(
      pinMinutes: pin,
      viewportY: weekAxisViewportY(
        axis: axis,
        pinMinutes: pin,
        scrollOffset: scrollOffset,
        bottomAlignPad: bottomAlignPad,
        topDockHeight: topDockHeight,
      ),
    );
  }

  /// Keep [viewportY], retarget to new minutes (e.g. after successful drop).
  WeekAxisViewportPin retargetMinutes(int minutes) {
    return WeekAxisViewportPin(
      pinMinutes: minutes.clamp(0, 24 * 60 - 1),
      viewportY: viewportY,
    );
  }

  /// Scroll offset that restores this pin on [newAxis].
  double scrollOffsetFor({
    required WeekHourAxis newAxis,
    required double maxScrollExtent,
    double bottomAlignPad = 0,
    double topDockHeight = 0,
  }) {
    return weekAxisKeepVisibleOffset(
      newAxis: newAxis,
      pinMinutes: pinMinutes,
      viewportY: viewportY,
      maxScrollExtent: maxScrollExtent,
      bottomAlignPad: bottomAlignPad,
      topDockHeight: topDockHeight,
    );
  }
}

/// Applies [pin] after the next frame (axis layout must settle first).
void weekAxisApplyPinPostFrame({
  required WeekAxisViewportPin pin,
  required WeekHourAxis axis,
  required double Function() maxScrollExtent,
  required void Function(double offset) jumpTo,
  double bottomAlignPad = 0,
  double topDockHeight = 0,
  bool Function()? isMounted,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (isMounted != null && !isMounted()) return;
    final maxExtent = maxScrollExtent();
    final target = pin.scrollOffsetFor(
      newAxis: axis,
      maxScrollExtent: maxExtent,
      bottomAlignPad: bottomAlignPad,
      topDockHeight: topDockHeight,
    );
    jumpTo(target);
  });
}

/// True when the scheduler is mid-build and setState is unsafe.
bool weekAxisSchedulerIsBuilding() {
  final phase = SchedulerBinding.instance.schedulerPhase;
  return phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks;
}
