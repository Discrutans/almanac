import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Общие настройки прокрутки под 90/120/144 Гц+.
///
/// Физика Flutter уже привязана к vsync (время, не кадры). Главное — не
/// перестраивать дерево на каждый указатель, префетчить больше пикселей и
/// не форсировать [ClampingScrollPhysics] там, где должен работать
/// [ScrollConfiguration].
abstract final class AlmanacScroll {
  /// Prefetch списков (inbox, события дня, настройки).
  static const double listCacheExtent = 800;

  /// Prefetch длинных календарных лент (agenda, year).
  static const double calendarCacheExtent = 960;

  /// Вертикальный список событий в колонке недели.
  static const double weekColumnCacheExtent = 480;

  /// Сколько колонок карусели держать за кадром.
  static const int carouselPrefetchColumns = 8;

  static const ScrollViewKeyboardDismissBehavior keyboardDismiss =
      ScrollViewKeyboardDismissBehavior.onDrag;

  /// Мышь и тачпад на десктопе 144 Гц, стилус на планшетах.
  static const Set<PointerDeviceKind> dragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };
}

/// Плавная прокрутка: платформенная физика + все указатели + без glow на desktop.
class AlmanacScrollBehavior extends MaterialScrollBehavior {
  const AlmanacScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => AlmanacScroll.dragDevices;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          decelerationRate: ScrollDecelerationRate.normal,
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return child;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return StretchingOverscrollIndicator(
          axisDirection: details.direction,
          clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge,
          child: child,
        );
    }
  }
}

/// Без desktop scrollbar (синхронные per-lane скроллеры карусели).
class AlmanacNoScrollbarBehavior extends AlmanacScrollBehavior {
  const AlmanacNoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Сколько колонок карусели префетчить в пикселях.
double weekCarouselCacheExtent(double columnWidth) {
  if (columnWidth <= 0) return AlmanacScroll.listCacheExtent;
  return columnWidth * AlmanacScroll.carouselPrefetchColumns;
}

/// Текущая герцовка окна (Flutter 3.13+ Display API), иначе 60.
double almanacDisplayRefreshRate() {
  try {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 60;
    final rate = views.first.display.refreshRate;
    if (rate.isFinite && rate >= 30) return rate;
  } on Object {
    if (kDebugMode) {
      debugPrint('Almanac: display refreshRate unavailable');
    }
  }
  return 60;
}
