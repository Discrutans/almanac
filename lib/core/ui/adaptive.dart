import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';
import 'almanac_panel_layout.dart';

/// Status / navigation / keyboard insets that survive edge-to-edge Android.
abstract final class AlmanacSystemInsets {
  static double top(MediaQueryData mq) => mq.viewPadding.top;

  static double bottom(MediaQueryData mq) =>
      math.max(mq.viewPadding.bottom, mq.viewInsets.bottom);

  static double left(MediaQueryData mq) => mq.viewPadding.left;

  static double right(MediaQueryData mq) => mq.viewPadding.right;
}

/// Адаптивные helpers поверх [AlmanacBreakpoints].
extension AlmanacAdaptiveContext on BuildContext {
  Size get almanacSize => MediaQuery.sizeOf(this);
  double get almanacWidth => almanacSize.width;
  bool get isMobileWidth => AlmanacBreakpoints.isMobile(almanacWidth);
  bool get isTabletWidth => AlmanacBreakpoints.isTablet(almanacWidth);
  bool get isDesktopWidth => AlmanacBreakpoints.isDesktop(almanacWidth);

  /// Отступы панели: на телефоне почти full-bleed, на широких экранах — padding.
  EdgeInsets get panelOuterPadding => AlmanacPanelLayout.outerPadding(
    screenWidth: almanacWidth,
    isBottom: false,
  );

  /// Высота expanded-панели на узких экранах чуть больше, чтобы формы не обрезались.
  double get panelMaxHeightFactor =>
      AlmanacPanelLayout.maxHeightFactor(almanacWidth);

  /// Компактная плотность для AppBar / toolbar.
  double get compactToolbarHeight =>
      isMobileWidth ? AlmanacSizes.topBarHeight - 4 : AlmanacSizes.topBarHeight;

  /// Нижний отступ sheet/dialog с учётом Android bar и клавиатуры.
  double get sheetBottomPadding =>
      AlmanacSystemInsets.bottom(MediaQuery.of(this)) + AlmanacSpacing.md;
  EdgeInsets get sheetBottomInsets =>
      EdgeInsets.only(bottom: sheetBottomPadding);
}
