import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'week_hour_axis.dart';

/// Shared pinch-to-zoom for week hour height (carousel + drop grid).
///
/// During the gesture height scales continuously between strip×1 and strip×3;
/// on release it snaps to the nearest level.
class WeekPinchHourController {
  WeekPinchHourController({
    int zoomLevel = kWeekHourZoomLevelDefault,
    double stripHeight = kWeekHourHeight,
  }) : _level = clampWeekHourZoomLevel(zoomLevel),
       _stripHeight = stripHeight > 0 ? stripHeight : kWeekHourHeight,
       _hourHeight = weekHourHeightForZoom(
         stripHeight > 0 ? stripHeight : kWeekHourHeight,
         clampWeekHourZoomLevel(zoomLevel),
       ),
       _pinchBaseHeight = weekHourHeightForZoom(
         stripHeight > 0 ? stripHeight : kWeekHourHeight,
         clampWeekHourZoomLevel(zoomLevel),
       );

  int _level;
  double _stripHeight;
  double _hourHeight;
  double _pinchBaseHeight;
  double? _pinchStartSpan;
  final _pointers = <int, Offset>{};

  int get zoomLevel => _level;
  double get hourHeight => _hourHeight;
  double get stripHeight => _stripHeight;
  bool get isPinching => _pointers.length >= 2;

  /// Sync from props when not mid-pinch. Returns true if [hourHeight] changed.
  bool syncFromProps({required int zoomLevel, required double stripHeight}) {
    if (isPinching) return false;
    final strip = stripHeight > 0 ? stripHeight : _stripHeight;
    final level = clampWeekHourZoomLevel(zoomLevel);
    final next = weekHourHeightForZoom(strip, level);
    final changed =
        (next - _hourHeight).abs() > 0.5 ||
        strip != _stripHeight ||
        level != _level;
    _stripHeight = strip;
    _level = level;
    _hourHeight = next;
    return changed;
  }

  /// Focal in global coords when the second finger just landed; else null.
  Offset? handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2) return null;
    _pinchBaseHeight = _hourHeight;
    _pinchStartSpan = _pinchSpan();
    return _pinchFocal();
  }

  /// Returns true if [hourHeight] changed.
  bool handlePointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return false;
    _pointers[event.pointer] = event.position;
    final startSpan = _pinchStartSpan;
    final span = _pinchSpan();
    if (startSpan == null || span == null || startSpan < 1) return false;
    final minH = weekHourHeightForZoom(_stripHeight, kWeekHourZoomLevelMin);
    final maxH = weekHourHeightForZoom(_stripHeight, kWeekHourZoomLevelMax);
    final next = (_pinchBaseHeight * (span / startSpan)).clamp(minH, maxH);
    if ((next - _hourHeight).abs() < 0.5) return false;
    _hourHeight = next;
    return true;
  }

  /// Snaps to nearest level when pinch ends. [snappedLevel] if level changed.
  ({bool heightChanged, int? snappedLevel}) handlePointerUp(
    PointerEvent event,
  ) {
    _pointers.remove(event.pointer);
    if (_pointers.length >= 2) {
      return (heightChanged: false, snappedLevel: null);
    }
    _pinchStartSpan = null;
    final snapped = weekHourZoomLevelNearest(_stripHeight, _hourHeight);
    final next = weekHourHeightForZoom(_stripHeight, snapped);
    final heightChanged = (next - _hourHeight).abs() > 0.5 || snapped != _level;
    final levelChanged = snapped != _level;
    _level = snapped;
    _hourHeight = next;
    return (
      heightChanged: heightChanged,
      snappedLevel: levelChanged ? snapped : null,
    );
  }

  double? _pinchSpan() {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.toList(growable: false);
    return (points[0] - points[1]).distance;
  }

  Offset? _pinchFocal() {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.toList(growable: false);
    return Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
  }

  @visibleForTesting
  void debugSetHourHeight(double height) {
    _hourHeight = height;
  }
}
