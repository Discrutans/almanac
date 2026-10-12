import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'calendar_day_badge.dart';
import 'date_cell.dart';

/// Строка из 7 ячеек дат — каждая под своим днём недели (1/7 ширины).
class CalendarDateRow extends StatelessWidget {
  const CalendarDateRow({
    super.key,
    required this.children,
    this.compact = false,
    this.useBadgeHeight = false,
  });

  final List<Widget> children;
  final bool compact;

  /// Высота строки под [CalendarDayBadge] (неделя); иначе — под [DateCell] (месяц).
  final bool useBadgeHeight;

  @override
  Widget build(BuildContext context) {
    assert(children.length == 7, 'CalendarDateRow expects exactly 7 cells');

    return LayoutBuilder(
      builder: (context, constraints) {
        final naturalHeight = useBadgeHeight
            ? CalendarDayBadgeLayout.weekStripHeightFromViewport(
                constraints.maxWidth,
              )
            : DateCellLayout.cellSide(constraints.maxWidth);
        final rowHeight = constraints.maxHeight.isFinite
            ? math.min(naturalHeight, constraints.maxHeight)
            : naturalHeight;

        return SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < 7; i++) Expanded(child: children[i]),
            ],
          ),
        );
      },
    );
  }
}
