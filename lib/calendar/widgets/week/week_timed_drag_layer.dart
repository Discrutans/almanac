import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../calendar_event_index.dart';
import 'week_grid_slot.dart';
import 'week_hold_move_recognizer.dart';
import 'week_hour_axis.dart';
import 'week_move_controller.dart';
import 'week_move_scope.dart';
import 'week_move_types.dart';
import 'week_selection_frame.dart';
import 'week_ui_tokens.dart';

/// Hold-to-move + drop preview over the **timed** viewport (no date strip).
class WeekTimedDragLayer extends StatefulWidget {
  const WeekTimedDragLayer({
    super.key,
    required this.move,
    required this.axis,
    required this.dates,
    required this.timedScroll,
    required this.allDayHeight,
    required this.columnWidth,
    required this.onActiveChanged,
    required this.onDragPointer,
    required this.onResult,
    required this.child,
    this.horizontalScroll,
    this.enabled = true,
  });

  final WeekMoveController move;
  final WeekHourAxis axis;
  final List<DateTime> dates;
  final ScrollController timedScroll;
  final ScrollController? horizontalScroll;
  final double allDayHeight;
  final double columnWidth;
  final void Function(bool active, int? pinMinutes) onActiveChanged;
  final ValueChanged<Offset> onDragPointer;
  final ValueChanged<WeekMoveResult> onResult;
  final bool enabled;
  final Widget child;

  @override
  State<WeekTimedDragLayer> createState() => _WeekTimedDragLayerState();
}

class _WeekTimedDragLayerState extends State<WeekTimedDragLayer>
    with WidgetsBindingObserver {
  WeekHoldMoveRecognizer? _recognizer;
  var _wasActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.move.addListener(_onMoveChanged);
    widget.timedScroll.addListener(_onScrollChanged);
    widget.horizontalScroll?.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant WeekTimedDragLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.move != widget.move) {
      oldWidget.move.removeListener(_onMoveChanged);
      widget.move.addListener(_onMoveChanged);
    }
    if (oldWidget.timedScroll != widget.timedScroll) {
      oldWidget.timedScroll.removeListener(_onScrollChanged);
      widget.timedScroll.addListener(_onScrollChanged);
    }
    final oldH = oldWidget.horizontalScroll;
    final newH = widget.horizontalScroll;
    if (oldH != newH) {
      oldH?.removeListener(_onScrollChanged);
      newH?.addListener(_onScrollChanged);
    }
    if (oldWidget.axis != widget.axis ||
        oldWidget.allDayHeight != widget.allDayHeight ||
        oldWidget.dates != widget.dates) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.move.refreshAfterLayout();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.move.removeListener(_onMoveChanged);
    widget.timedScroll.removeListener(_onScrollChanged);
    widget.horizontalScroll?.removeListener(_onScrollChanged);
    if (widget.move.active) {
      widget.move.cancel();
      widget.onResult(const WeekMoveCancelled());
    }
    super.dispose();
  }

  void _onScrollChanged() {
    if (widget.move.active) {
      widget.move.refreshAfterLayout();
    }
  }

  void _onMoveChanged() {
    final active = widget.move.active;
    if (active == _wasActive) return;
    _wasActive = active;
    final pin = active ? widget.move.payload?.pinMinutes : null;
    widget.onActiveChanged(active, pin);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cancelActiveMove();
    }
  }

  void _cancelActiveMove() {
    if (!widget.move.active) return;
    widget.move.cancel();
    widget.onResult(const WeekMoveCancelled());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (!widget.move.active) return KeyEventResult.ignored;
    _cancelActiveMove();
    return KeyEventResult.handled;
  }

  WeekHoldMoveRecognizer _createRecognizer() {
    return WeekHoldMoveRecognizer(
      delay: const Duration(milliseconds: 380),
      resolveDelay: () =>
          widget.move.pendingDelay ?? const Duration(milliseconds: 380),
      allowPointer: (pointer) {
        return widget.move.pendingPointer == pointer &&
            widget.move.hasPendingCandidate;
      },
    )
      ..onHoldAccepted = _onHoldAccepted
      ..onHoldRejected = _onHoldRejected
      ..onPointerMove = _onRecognizerMove
      ..onPointerUp = _onRecognizerUp
      ..onPointerCancel = _onRecognizerCancel;
  }

  void _onHoldAccepted(Offset origin) {
    final pointer = widget.move.pendingPointer;
    if (pointer == null) return;
    final candidate = widget.move.takeCandidate(pointer);
    if (candidate == null) return;
    final global = widget.move.pendingGlobal ?? origin;
    widget.move.start(candidate, global: global);
    unawaited(HapticFeedback.mediumImpact());
  }

  void _onHoldRejected() {
    final pointer = widget.move.pendingPointer;
    if (pointer != null) {
      widget.move.clearOffer(pointer);
    }
  }

  void _onRecognizerMove(PointerMoveEvent event) {
    if (!widget.move.active) return;
    widget.move.pointerMove(event.position);
    widget.onDragPointer(event.position);
  }

  void _onRecognizerUp() {
    if (!widget.move.active) return;
    final result = widget.move.commit();
    widget.move.finish();
    widget.onResult(result);
  }

  void _onRecognizerCancel() {
    if (!widget.move.active) {
      final pointer = widget.move.pendingPointer;
      if (pointer != null) {
        widget.move.clearOffer(pointer);
      }
      return;
    }
    widget.move.cancel();
    widget.onResult(const WeekMoveCancelled());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return WeekMoveScope(controller: widget.move, child: widget.child);
    }

    final listenables = <Listenable>[widget.move, widget.timedScroll];
    final horizontal = widget.horizontalScroll;
    if (horizontal != null) listenables.add(horizontal);

    return WeekMoveScope(
      controller: widget.move,
      child: Focus(
        onKeyEvent: _onKeyEvent,
        child: RawGestureDetector(
        gestures: {
          WeekHoldMoveRecognizer:
              GestureRecognizerFactoryWithHandlers<WeekHoldMoveRecognizer>(
            () {
              _recognizer ??= _createRecognizer();
              return _recognizer!;
            },
            (_) {},
          ),
        },
        behavior: HitTestBehavior.deferToChild,
        child: ListenableBuilder(
          listenable: Listenable.merge(listenables),
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final preview = widget.move.preview;
                final highlight = widget.move.highlightDate;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.child,
                    if (highlight != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _WeekColumnHighlightOverlay(
                            highlightDate: highlight,
                            dates: widget.dates,
                            columnWidth: widget.columnWidth,
                            horizontalScroll: horizontal,
                            timedScroll: widget.timedScroll,
                            viewportHeight: constraints.maxHeight,
                            bodyHeight:
                                widget.allDayHeight + widget.axis.totalHeight,
                            allDayHeight: widget.allDayHeight,
                            axisHeight: widget.axis.totalHeight,
                          ),
                        ),
                      ),
                    if (preview != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: WeekDropPreviewOverlay(
                            preview: preview,
                            axis: widget.axis,
                            dates: widget.dates,
                            columnWidth: widget.columnWidth,
                            timedScroll: widget.timedScroll,
                            horizontalScroll: horizontal,
                            viewportHeight: constraints.maxHeight,
                            bodyHeight:
                                widget.allDayHeight + widget.axis.totalHeight,
                            allDayHeight: widget.allDayHeight,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
        ),
      ),
    );
  }
}

class _WeekColumnHighlightOverlay extends StatelessWidget {
  const _WeekColumnHighlightOverlay({
    required this.highlightDate,
    required this.dates,
    required this.columnWidth,
    required this.timedScroll,
    required this.viewportHeight,
    required this.bodyHeight,
    required this.allDayHeight,
    required this.axisHeight,
    this.horizontalScroll,
  });

  final DateTime highlightDate;
  final List<DateTime> dates;
  final double columnWidth;
  final ScrollController timedScroll;
  final ScrollController? horizontalScroll;
  final double viewportHeight;
  final double bodyHeight;
  final double allDayHeight;
  final double axisHeight;

  @override
  Widget build(BuildContext context) {
    final index = dates.indexWhere(
      (date) => isSameCalendarDay(date, highlightDate),
    );
    if (index < 0 || columnWidth <= 0) return const SizedBox.shrink();

    final hOffset = horizontalScroll != null && horizontalScroll!.hasClients
        ? horizontalScroll!.offset
        : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return WeekTimedScrollLayer(
      scrollController: timedScroll,
      viewportHeight: viewportHeight,
      bodyHeight: bodyHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: index * columnWidth - hOffset,
            width: columnWidth,
            top: allDayHeight,
            height: axisHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary.withValues(
                  alpha: WeekUiTokens.dropHighlightFillAlpha,
                ),
                border: Border(
                  top: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.5),
                    width: WeekUiTokens.dropHighlightBorderWidth,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Landing contour in the same coordinate space as [weekDropTargetAt].
class WeekDropPreviewOverlay extends StatelessWidget {
  const WeekDropPreviewOverlay({
    super.key,
    required this.preview,
    required this.axis,
    required this.dates,
    required this.columnWidth,
    required this.timedScroll,
    required this.viewportHeight,
    required this.bodyHeight,
    required this.allDayHeight,
    this.horizontalScroll,
  });

  final WeekDropPreview preview;
  final WeekHourAxis axis;
  final List<DateTime> dates;
  final double columnWidth;
  final ScrollController timedScroll;
  final ScrollController? horizontalScroll;
  final double viewportHeight;
  final double bodyHeight;
  final double allDayHeight;

  @override
  Widget build(BuildContext context) {
    final index = dates.indexWhere((date) => preview.isOnDate(date));
    if (index < 0 || columnWidth <= 0) return const SizedBox.shrink();

    final hOffset = horizontalScroll != null && horizontalScroll!.hasClients
        ? horizontalScroll!.offset
        : 0.0;
    final accent = Theme.of(context).colorScheme.primary;

    return WeekTimedScrollLayer(
      scrollController: timedScroll,
      viewportHeight: viewportHeight,
      bodyHeight: bodyHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: index * columnWidth - hOffset,
            width: columnWidth,
            top: allDayHeight,
            height: axis.totalHeight,
            child: WeekSelectionFrame(
              key: WeekDropPreview.previewKey,
              axis: axis,
              startMinutes: preview.startMinutes,
              endMinutes: preview.endMinutes,
              color: accent,
              showHandles: false,
              fillAlpha: WeekUiTokens.previewFillAlpha,
              borderWidth: WeekUiTokens.previewBorderWidth,
            ),
          ),
        ],
      ),
    );
  }
}
