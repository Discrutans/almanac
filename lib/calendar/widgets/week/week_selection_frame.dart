import 'package:flutter/material.dart';

import '../../calendar_types.dart';
import 'week_event_cell_contour.dart';
import 'week_grid_slot.dart';
import 'week_hour_axis.dart';
import 'week_ui_tokens.dart';

/// Рамка выделенного слота/события с круглыми ручками верх-лево и низ-право.
///
/// Тело: pointer down → [onBodyPointerDown] (hold распознаёт timed-слой).
class WeekSelectionFrame extends StatelessWidget {
  const WeekSelectionFrame({
    super.key,
    required this.axis,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    this.showHandles = true,
    this.fillAlpha = WeekUiTokens.slotFillAlpha,
    this.borderWidth = WeekUiTokens.slotBorderWidth,
    this.liveMinutes,
    this.onStartHandleDrag,
    this.onEndHandleDrag,
    this.onHandleDragEnd,
    this.dragSlot,
    this.dragEvent,
    this.onBodyPointerDown,
    this.dragging = false,
  });

  static const frameKey = ValueKey('week-selection-frame');
  static const startHandleKey = ValueKey('week-resize-handle-start');
  static const endHandleKey = ValueKey('week-resize-handle-end');
  static const bodyDragKey = ValueKey('week-selection-body-drag');

  final WeekHourAxis axis;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final bool showHandles;
  final double fillAlpha;
  final double borderWidth;
  final int? liveMinutes;
  final GestureDragUpdateCallback? onStartHandleDrag;
  final GestureDragUpdateCallback? onEndHandleDrag;
  final VoidCallback? onHandleDragEnd;
  final WeekGridSlot? dragSlot;
  final AppEvent? dragEvent;
  final void Function(PointerDownEvent event)? onBodyPointerDown;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final rawTop = axis.yForMinutes(startMinutes);
    final rawBottom = axis.yForMinutes(endMinutes);
    final top = rawTop <= rawBottom ? rawTop : rawBottom;
    final bottom = rawTop <= rawBottom ? rawBottom : rawTop;
    final height = (bottom - top).clamp(
      kWeekHourMinEventHeight,
      axis.totalHeight > 0 ? axis.totalHeight : kWeekHourMinEventHeight * 8,
    );
    final canBodyDrag =
        onBodyPointerDown != null &&
        height < axis.totalHeight * 0.95 &&
        (dragSlot != null || dragEvent != null);

    Widget? bodyHit;
    if (canBodyDrag) {
      bodyHit = Positioned(
        key: bodyDragKey,
        top: top,
        left: 0,
        right: 0,
        height: height,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: onBodyPointerDown,
          child: const ColoredBox(
            color: Color(0x01000000),
            child: SizedBox.expand(),
          ),
        ),
      );
    }

    return Opacity(
      opacity: dragging ? WeekUiTokens.frameDraggingOpacity : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: frameKey,
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                painter: WeekEventCellContourPainter(
                  axis: axis,
                  startMinutes: startMinutes,
                  endMinutes: endMinutes,
                  color: color.withValues(alpha: fillAlpha),
                  originY: 0,
                  borderColor: color,
                  borderWidth: borderWidth,
                ),
              ),
            ),
          ),
          if (bodyHit != null) bodyHit,
          if (showHandles) ...[
            Positioned(
              top: top - kWeekHourResizeHandleExtent / 2,
              left: 0,
              child: _Handle(
                key: startHandleKey,
                color: color,
                onDragUpdate: onStartHandleDrag,
                onDragEnd: onHandleDragEnd,
              ),
            ),
            Positioned(
              top: bottom - kWeekHourResizeHandleExtent / 2,
              right: 0,
              child: _Handle(
                key: endHandleKey,
                color: color,
                onDragUpdate: onEndHandleDrag,
                onDragEnd: onHandleDragEnd,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    super.key,
    required this.color,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Color color;
  final GestureDragUpdateCallback? onDragUpdate;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerMove: onDragUpdate == null
          ? null
          : (event) {
              if (event.down) {
                onDragUpdate!(
                  DragUpdateDetails(
                    globalPosition: event.position,
                    delta: event.delta,
                  ),
                );
              }
            },
      onPointerUp: onDragEnd == null ? null : (_) => onDragEnd!(),
      onPointerCancel: onDragEnd == null ? null : (_) => onDragEnd!(),
      child: SizedBox(
        width: kWeekHourResizeHandleExtent,
        height: kWeekHourResizeHandleExtent,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const SizedBox(
              width: kWeekResizeHandleSize,
              height: kWeekResizeHandleSize,
            ),
          ),
        ),
      ),
    );
  }
}
