import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_event_index.dart';
import 'week_hour_axis.dart';

/// Подпись часа: `08:00` у верха блока.
String formatWeekHourLabel(int hour) {
  if (hour < 0 || hour >= 24) return '';
  return '${hour.toString().padLeft(2, '0')}:00';
}

String formatWeekMinutesLabel(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60);
  if (clamped >= 24 * 60) return '24:00';
  final hour = clamped ~/ 60;
  final minute = clamped % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

List<double> weekHourGridHourYs(WeekHourAxis axis) {
  return [
    for (final segment in axis.segments)
      if (segment.isHour) segment.y,
    if (axis.segments.isNotEmpty) axis.totalHeight,
  ];
}

List<double> weekHourGridHalfHourYs(WeekHourAxis axis) {
  return [
    for (final segment in axis.segments)
      if (segment.isHour) segment.y + segment.height / 2,
  ];
}

class WeekHourGridLines extends StatelessWidget {
  const WeekHourGridLines({
    super.key,
    required this.axis,
    this.monolithic = false,
  });

  final WeekHourAxis axis;

  /// Одна непрерывная плоскость на всю ширину (wide week), без стыков по дням.
  final bool monolithic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(double.infinity, axis.totalHeight),
      painter: _WeekHourGridPainter(
        axis: axis,
        cellColor: scheme.surfaceContainerHighest,
        halfHourColor: scheme.outlineVariant.withValues(alpha: 0.18),
        monolithic: monolithic,
      ),
    );
  }
}

class _WeekHourGridPainter extends CustomPainter {
  _WeekHourGridPainter({
    required this.axis,
    required this.cellColor,
    required this.halfHourColor,
    this.monolithic = false,
  });

  final WeekHourAxis axis;
  final Color cellColor;
  final Color halfHourColor;
  final bool monolithic;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = cellColor;
    final halfPaint = Paint()
      ..color = halfHourColor
      ..strokeWidth = 1;
    final radius = Radius.circular(kWeekHourCellRadius);

    for (final segment in axis.segments) {
      if (!segment.isHour) continue;
      final Rect rect;
      if (monolithic) {
        const inset = kWeekHourCellInset;
        final height = (segment.height - inset * 2).clamp(4.0, segment.height);
        rect = Rect.fromLTWH(0, segment.y + inset, size.width, height);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: radius,
            bottomLeft: radius,
            topRight: radius,
            bottomRight: radius,
          ),
          fill,
        );
      } else {
        rect = weekHourCellRect(segment: segment, width: size.width);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
      }
      final midY = segment.y + segment.height / 2;
      canvas.drawLine(
        Offset(rect.left + 4, midY),
        Offset(rect.right - 4, midY),
        halfPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeekHourGridPainter oldDelegate) {
    return oldDelegate.axis != axis ||
        oldDelegate.cellColor != cellColor ||
        oldDelegate.halfHourColor != halfHourColor ||
        oldDelegate.monolithic != monolithic;
  }
}

/// Zoom factor for hour labels relative to the default hour row height.
double weekHourLabelZoom(double hourHeight) {
  return (hourHeight / kWeekHourHeight).clamp(
    kWeekHourHeightMin / kWeekHourHeight,
    kWeekHourHeightMax / kWeekHourHeight,
  );
}

/// Font size that stays readable when the week grid is pinched.
double weekHourLabelFontSize(double hourHeight) {
  return (10.0 * weekHourLabelZoom(hourHeight)).clamp(8.0, 14.0);
}

/// Horizontal slot for `HH:00` chips (scales with zoom so text never wraps).
double weekHourLabelSlotWidth(double hourHeight) {
  return (54.0 * weekHourLabelZoom(hourHeight)).clamp(48.0, 68.0);
}

class WeekHourLabels extends StatelessWidget {
  const WeekHourLabels({super.key, required this.axis, this.liveMinutes});

  final WeekHourAxis axis;
  final int? liveMinutes;

  @override
  Widget build(BuildContext context) {
    final muted = context.almanacColors.muted;
    final scheme = Theme.of(context).colorScheme;
    final fontSize = weekHourLabelFontSize(axis.hourHeight);
    final slotWidth = weekHourLabelSlotWidth(axis.hourHeight);
    final padH = (2.5 * weekHourLabelZoom(axis.hourHeight)).clamp(2.0, 4.0);
    final padV = (1.5 * weekHourLabelZoom(axis.hourHeight)).clamp(1.0, 3.0);
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: muted,
      fontSize: fontSize,
      height: 1,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return IgnorePointer(
      child: SizedBox(
        width: slotWidth,
        height: axis.totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final segment in axis.segments)
              if (segment.isHour &&
                  formatWeekHourLabel(segment.hour).isNotEmpty)
                Positioned(
                  left: 0,
                  width: slotWidth,
                  top: segment.y + kWeekHourCellInset,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _WeekHourLabelChip(
                      text: formatWeekHourLabel(segment.hour),
                      style: labelStyle,
                      padH: padH,
                      padV: padV,
                      fill: scheme.surface.withValues(alpha: 0.94),
                      border: scheme.outline.withValues(alpha: 0.55),
                    ),
                  ),
                ),
            if (liveMinutes != null)
              Positioned(
                left: 0,
                width: slotWidth,
                top: axis.yForMinutes(liveMinutes!) - fontSize / 2 - padV,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _WeekHourLabelChip(
                    text: formatWeekMinutesLabel(liveMinutes!),
                    style: labelStyle?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    padH: padH,
                    padV: padV,
                    fill: scheme.surface.withValues(alpha: 0.96),
                    border: scheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekHourLabelChip extends StatelessWidget {
  const _WeekHourLabelChip({
    required this.text,
    required this.style,
    required this.padH,
    required this.padV,
    required this.fill,
    required this.border,
  });

  final String text;
  final TextStyle? style;
  final double padH;
  final double padV;
  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AlmanacRadius.xxs),
        border: Border.all(color: border, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.left,
          style: style,
        ),
      ),
    );
  }
}

/// Красная линия «сейчас» на сегодняшней колонке.
class WeekNowLine extends StatefulWidget {
  const WeekNowLine({
    super.key,
    required this.axis,
    required this.date,
  });

  static const lineKey = ValueKey('week-now-line');
  static const dotKey = ValueKey('week-now-dot');

  final WeekHourAxis axis;
  final DateTime date;

  @override
  State<WeekNowLine> createState() => _WeekNowLineState();
}

class _WeekNowLineState extends State<WeekNowLine> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isSameCalendarDay(widget.date, DateTime.now())) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    final y = weekNowLineY(widget.axis, minutes);
    if (y == null) {
      // Now falls in a collapsed gutter — hide rather than misplace.
      return const SizedBox.shrink();
    }
    final color = AlmanacBrand.accentEnd;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: y - 0.5,
          height: 1,
          child: ColoredBox(key: WeekNowLine.lineKey, color: color),
        ),
        Positioned(
          left: -3,
          top: y - 3.5,
          child: DecoratedBox(
            key: WeekNowLine.dotKey,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: const SizedBox(width: 7, height: 7),
          ),
        ),
      ],
    );
  }
}
