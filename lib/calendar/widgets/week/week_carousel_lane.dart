import 'package:flutter/material.dart';
import 'week_carousel_snap_physics.dart';

/// Горизонтальная «дорожка» карусели недели с боковым padding.
///
/// Центрирует первый и последний день недели на snap-позициях min/max.
class WeekCarouselLane extends StatelessWidget {
  const WeekCarouselLane({
    super.key,
    required this.columnWidth,
    required this.dayCount,
    required this.childBuilder,
    this.controller,
    this.viewportWidth,
    this.visibleDays = 3,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final double columnWidth;
  final int dayCount;
  final int visibleDays;
  final double? viewportWidth;
  final ScrollController? controller;
  final CrossAxisAlignment crossAxisAlignment;
  final Widget Function(int dayIndex) childBuilder;

  double get _viewportWidth =>
      viewportWidth ??
      weekCarouselViewportWidth(columnWidth, visibleDays: visibleDays);

  double get _padding => weekCarouselHorizontalPadding(
    viewportDimension: _viewportWidth,
    columnWidth: columnWidth,
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      scrollDirection: Axis.horizontal,
      physics: weekCarouselSnapScrollPhysics(columnWidth),
      child: SizedBox(
        width: _padding * 2 + columnWidth * dayCount,
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            SizedBox(width: _padding),
            for (var i = 0; i < dayCount; i++)
              SizedBox(width: columnWidth, child: childBuilder(i)),
            SizedBox(width: _padding),
          ],
        ),
      ),
    );
  }
}
