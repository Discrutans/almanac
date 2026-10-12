import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'week_hour_axis.dart';

/// Заливка события внутри квадратных ячеек сетки (час или доля, напр. 15 мин).
///
/// Геометрия и радиус совпадают с пустой сеткой ([weekHourCellRect]).
/// Обводка — по каждой ячейке (как у пустых часов), не один силуэт.
class WeekEventCellContourPainter extends CustomPainter {
  WeekEventCellContourPainter({
    required this.axis,
    required this.startMinutes,
    required this.endMinutes,
    required this.color,
    required this.originY,
    this.borderColor,
    this.borderWidth = 0,
  });

  final WeekHourAxis axis;
  final int startMinutes;
  final int endMinutes;
  final Color color;
  final double originY;
  final Color? borderColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final border = borderColor == null || borderWidth <= 0
        ? null
        : (Paint()
            ..color = borderColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderWidth);
    const radius = kWeekHourCellRadius;

    final pieces = weekEventFillPieces(
      axis: axis,
      width: size.width,
      originY: originY,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    for (final piece in pieces) {
      final rrect = weekEventFillRRect(
        fill: piece.fill,
        cell: piece.cell,
        radius: radius,
      );
      canvas.drawRRect(rrect, fill);
      if (border != null) {
        canvas.drawRRect(rrect, border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeekEventCellContourPainter oldDelegate) {
    return oldDelegate.axis != axis ||
        oldDelegate.startMinutes != startMinutes ||
        oldDelegate.endMinutes != endMinutes ||
        oldDelegate.color != color ||
        oldDelegate.originY != originY ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

/// Пара заливка + ячейка для одного сегмента оси.
typedef WeekEventFillPiece = ({Rect fill, Rect cell});

/// Куски заливки события по сегментам оси (без gutter-дыр между часами).
List<WeekEventFillPiece> weekEventFillPieces({
  required WeekHourAxis axis,
  required double width,
  required double originY,
  required int startMinutes,
  required int endMinutes,
}) {
  final pieces = <WeekEventFillPiece>[];
  for (final segment in axis.segments) {
    final cell = weekHourCellRect(
      segment: segment,
      width: width,
      originY: originY,
    );
    final rect = weekEventFillRectInSegment(
      segment: segment,
      width: width,
      originY: originY,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );
    if (rect == null || rect.height <= 0.5 || rect.width <= 0) continue;
    pieces.add((fill: rect, cell: cell));
  }
  return pieces;
}

/// Пересечение интервала события с сегментом оси → rect заливки в локали тайла.
///
/// Для часового сегмента доля высоты = доля минут (15 мин ≈ ¼ ячейки).
/// Gutter тоже заливается, если событие его перекрывает.
Rect? weekEventFillRectInSegment({
  required WeekHourSegment segment,
  required double width,
  required double originY,
  required int startMinutes,
  required int endMinutes,
}) {
  final segStart = segment.startHour * 60;
  final segEnd = segment.endHourExclusive * 60;
  final clipStart = math.max(startMinutes, segStart);
  final clipEnd = math.min(endMinutes, segEnd);
  if (clipEnd <= clipStart) return null;

  final cell = weekHourCellRect(
    segment: segment,
    width: width,
    originY: originY,
  );
  final span = (segEnd - segStart).clamp(1, 24 * 60);
  final top = cell.top + cell.height * ((clipStart - segStart) / span);
  final bottom = cell.top + cell.height * ((clipEnd - segStart) / span);
  if (bottom - top < 1) {
    return Rect.fromLTWH(cell.left, top, cell.width, 1);
  }
  return Rect.fromLTRB(cell.left, top, cell.right, bottom);
}

/// Скругление только у углов, совпадающих с квадратной ячейкой сетки.
RRect weekEventFillRRect({
  required Rect fill,
  required Rect cell,
  required double radius,
}) {
  const eps = 0.75;
  final r = Radius.circular(radius);
  const zero = Radius.zero;
  return RRect.fromRectAndCorners(
    fill,
    topLeft: (fill.top - cell.top).abs() <= eps ? r : zero,
    topRight: (fill.top - cell.top).abs() <= eps ? r : zero,
    bottomLeft: (fill.bottom - cell.bottom).abs() <= eps ? r : zero,
    bottomRight: (fill.bottom - cell.bottom).abs() <= eps ? r : zero,
  );
}
