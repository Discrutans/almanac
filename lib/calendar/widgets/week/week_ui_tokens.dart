import 'package:flutter/material.dart';

import 'week_hour_axis.dart';

/// Visual / interaction tokens for week grid (carousel + wide).
abstract final class WeekUiTokens {
  /// Ghost lanes outside the selected week (carousel).
  static const double ghostOpacity = 0.38;

  /// Source tile while dragging (`childWhenDragging`).
  static const double draggingSourceOpacity = 0.24;

  /// Selection frame while its body is being dragged.
  static const double frameDraggingOpacity = 0.28;

  /// Selected create-slot fill / border.
  static const double slotFillAlpha = 0.22;
  static const double slotBorderWidth = 2;

  /// Armed (unlocked) event frame — between idle and slot.
  static const double armedFillAlpha = 0.16;
  static const double armedBorderWidth = 2;

  /// Drop landing preview — weaker than slot, no handles.
  /// Keep readable on cell fills (0.10 was nearly invisible).
  static const double previewFillAlpha = 0.15;
  static const double previewBorderWidth = 1.75;

  /// Timed tile text density thresholds (multiples of hour height unless noted).
  static const double tileHideTimeHeightPx = 28;
  static const double tileTwoLineHours = 1.5;
  static const double tileRangeTimeHours = 2;
  static const double tileNarrowContentWidth = 40;
  static const double tileHideTextWidth = 16;

  /// Drop-target column chrome.
  static const double dropHighlightBorderWidth = 2;
  static const double dropHighlightFillAlpha = 0.16;
}

/// Scroll-synced layer: paints [child] in timed-content coordinates
/// (bottom-aligned body, translated by [scrollController] offset).
class WeekTimedScrollLayer extends StatelessWidget {
  const WeekTimedScrollLayer({
    super.key,
    required this.scrollController,
    required this.viewportHeight,
    required this.bodyHeight,
    required this.child,
  });

  final ScrollController scrollController;
  final double viewportHeight;
  final double bodyHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, _) {
        final offset = scrollController.hasClients
            ? scrollController.offset
            : 0.0;
        final contentHeight = weekTimedScrollExtent(
          contentHeight: bodyHeight,
          viewportHeight: viewportHeight,
        );
        return Transform.translate(
          offset: Offset(0, -offset),
          child: SizedBox(
            height: contentHeight,
            width: double.infinity,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SizedBox(
                height: bodyHeight,
                width: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
