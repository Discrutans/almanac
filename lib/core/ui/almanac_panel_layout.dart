import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Как панель занимает высоту экрана.
enum AlmanacPanelSize {
  /// По контенту, с потолком по экрану (подтверждения, пикеры).
  hug,

  /// Формы и длинные списки — до потолка высоты.
  expanded,

  /// На всю доступную область окна.
  cover,
}

/// Единые ширина, высота и отступы модальных панелей.
abstract final class AlmanacPanelLayout {
  static const double compactMaxWidth = 420;
  static const double formMaxWidth = 560;

  static double maxWidth(
    double screenWidth, {
    bool compact = false,
    AlmanacPanelSize size = AlmanacPanelSize.expanded,
  }) {
    if (size == AlmanacPanelSize.cover) return screenWidth;
    if (AlmanacBreakpoints.isMobile(screenWidth)) return screenWidth;
    return compact ? compactMaxWidth : formMaxWidth;
  }

  static double maxHeightFactor(
    double screenWidth, {
    AlmanacPanelSize size = AlmanacPanelSize.expanded,
  }) {
    if (size == AlmanacPanelSize.cover) return 1;
    final mobile = AlmanacBreakpoints.isMobile(screenWidth);
    if (size == AlmanacPanelSize.hug) {
      return mobile ? 0.78 : 0.64;
    }
    if (mobile) return 0.94;
    if (AlmanacBreakpoints.isTablet(screenWidth)) return 0.86;
    return 0.82;
  }

  static EdgeInsets outerPadding({
    required double screenWidth,
    required bool isBottom,
    AlmanacPanelSize size = AlmanacPanelSize.expanded,
  }) {
    if (size == AlmanacPanelSize.cover) return EdgeInsets.zero;
    if (AlmanacBreakpoints.isMobile(screenWidth)) {
      if (isBottom) return EdgeInsets.zero;
      return const EdgeInsets.symmetric(horizontal: AlmanacSpacing.xs);
    }
    final horizontal = AlmanacBreakpoints.isDesktop(screenWidth)
        ? AlmanacSpacing.lg
        : AlmanacSpacing.md;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  static BorderRadius borderRadius({
    required bool isBottom,
    AlmanacPanelSize size = AlmanacPanelSize.expanded,
  }) {
    if (size == AlmanacPanelSize.cover) return BorderRadius.zero;
    return isBottom ? AlmanacRadius.sheetTop : AlmanacRadius.sheetBottom;
  }
}
