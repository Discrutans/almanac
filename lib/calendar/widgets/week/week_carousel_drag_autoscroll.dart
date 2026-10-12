import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Автопрокрутка карусели/шкалы недели, пока событие тащат или растягивают
/// у края экрана.
///
/// Смещение масштабируется по реальному dt vsync (90–144 Hz), а не по
/// фиксированным 16 мс.
class WeekCarouselDragAutoScroller {
  WeekCarouselDragAutoScroller({
    required this.viewportKey,
    this.scrollController,
    this.onScrollBy,
    this.onVerticalScrollBy,
    this.timedTopInset,
    this.horizontalEnabled = true,
    this.onShiftWeek,
    this.canShiftToPreviousWeek,
    this.canShiftToNextWeek,
    this.edgeZone = 56,
    this.maxSpeed = 14,
    this.weekShiftHoldDuration = const Duration(milliseconds: 280),
  });

  final GlobalKey viewportKey;
  final ScrollController? scrollController;
  final ValueChanged<double>? onScrollBy;
  final ValueChanged<double>? onVerticalScrollBy;

  /// Верх timed-области относительно viewport (strip + all-day).
  final ValueGetter<double>? timedTopInset;
  final bool horizontalEnabled;
  final ValueChanged<bool>? onShiftWeek;
  final bool Function()? canShiftToPreviousWeek;
  final bool Function()? canShiftToNextWeek;
  final double edgeZone;

  /// Пикселей за кадр при 60 Hz на полном краю; на высокой герцовке
  /// умножается на dt / (1/60).
  final double maxSpeed;
  final Duration weekShiftHoldDuration;

  static const _referenceFrame = Duration(milliseconds: 16);

  int? _frameId;
  Duration? _lastElapsed;
  double _horizontalDirection = 0;
  double _verticalDirection = 0;
  DateTime? _edgeHoldStarted;
  bool _weekShiftTriggered = false;
  Offset? _lastGlobalPosition;

  Offset? get lastGlobalPosition => _lastGlobalPosition;

  void updateDragPosition(
    Offset globalPosition, {
    bool? horizontalEnabled,
  }) {
    _lastGlobalPosition = globalPosition;
    final useHorizontal = horizontalEnabled ?? this.horizontalEnabled;

    final context = viewportKey.currentContext;
    if (context == null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(globalPosition);
    final width = box.size.width;
    final height = box.size.height;
    final topInset = (timedTopInset?.call() ?? 0).clamp(0.0, height);

    if (useHorizontal && onScrollBy != null) {
      if (local.dx < edgeZone) {
        _horizontalDirection =
            -((edgeZone - local.dx) / edgeZone).clamp(0.0, 1.0);
      } else if (local.dx > width - edgeZone) {
        _horizontalDirection =
            ((local.dx - (width - edgeZone)) / edgeZone).clamp(0.0, 1.0);
      } else {
        _horizontalDirection = 0;
        _edgeHoldStarted = null;
        _weekShiftTriggered = false;
      }
    } else {
      _horizontalDirection = 0;
      _edgeHoldStarted = null;
      _weekShiftTriggered = false;
    }

    if (onVerticalScrollBy != null) {
      final timedBottom = height;
      final timedTop = topInset;
      final fromTop = local.dy - timedTop;
      final fromBottom = timedBottom - local.dy;
      if (fromTop >= 0 && fromTop < edgeZone) {
        _verticalDirection = -((edgeZone - fromTop) / edgeZone).clamp(0.0, 1.0);
      } else if (fromBottom >= 0 && fromBottom < edgeZone) {
        _verticalDirection =
            ((edgeZone - fromBottom) / edgeZone).clamp(0.0, 1.0);
      } else {
        _verticalDirection = 0;
      }
    } else {
      _verticalDirection = 0;
    }

    if (_horizontalDirection == 0 && _verticalDirection == 0) {
      _stopTicker();
      return;
    }

    _ensureTicker();
  }

  void resumeAfterWeekShift([Offset? globalPosition]) {
    _weekShiftTriggered = false;
    _edgeHoldStarted = null;
    final position = globalPosition ?? _lastGlobalPosition;
    if (position == null) return;
    updateDragPosition(position);
  }

  void stop() {
    _horizontalDirection = 0;
    _verticalDirection = 0;
    _edgeHoldStarted = null;
    _weekShiftTriggered = false;
    _lastGlobalPosition = null;
    _stopTicker();
  }

  void _ensureTicker() {
    if (_frameId != null) return;
    _lastElapsed = null;
    _frameId = SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _stopTicker() {
    final id = _frameId;
    if (id != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
      _frameId = null;
    }
    _lastElapsed = null;
  }

  void _onFrame(Duration elapsed) {
    _frameId = null;
    if (_horizontalDirection == 0 && _verticalDirection == 0) {
      _lastElapsed = null;
      return;
    }

    final last = _lastElapsed ?? elapsed;
    _lastElapsed = elapsed;
    var dt = (elapsed - last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.05) {
      dt = _referenceFrame.inMicroseconds / 1e6;
    }

    final frameScale = dt / (_referenceFrame.inMicroseconds / 1e6);
    final step = maxSpeed * frameScale;
    if (_horizontalDirection != 0) {
      onScrollBy?.call(_horizontalDirection * step);
    }
    if (_verticalDirection != 0) {
      onVerticalScrollBy?.call(_verticalDirection * step);
    }
    _maybeShiftWeek();
    _frameId = SchedulerBinding.instance.scheduleFrameCallback(_onFrame);
  }

  void _maybeShiftWeek() {
    if (_horizontalDirection == 0) return;
    final controller = scrollController;
    if (onShiftWeek == null || controller == null || !controller.hasClients) {
      return;
    }

    final position = controller.position;
    const epsilon = 2.0;
    final atMin = position.pixels <= position.minScrollExtent + epsilon;
    final atMax = position.pixels >= position.maxScrollExtent - epsilon;

    if (_horizontalDirection < 0 && atMin) {
      if (canShiftToPreviousWeek?.call() ?? true) {
        _triggerWeekShift(nextWeek: false);
      }
    } else if (_horizontalDirection > 0 && atMax) {
      if (canShiftToNextWeek?.call() ?? true) {
        _triggerWeekShift(nextWeek: true);
      }
    } else {
      _edgeHoldStarted = null;
      _weekShiftTriggered = false;
    }
  }

  void _triggerWeekShift({required bool nextWeek}) {
    if (_weekShiftTriggered) return;

    _edgeHoldStarted ??= DateTime.now();
    if (DateTime.now().difference(_edgeHoldStarted!) < weekShiftHoldDuration) {
      return;
    }

    _weekShiftTriggered = true;
    onShiftWeek!(nextWeek);
  }

  void dispose() {
    stop();
  }
}
