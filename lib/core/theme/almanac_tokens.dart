import 'package:flutter/material.dart';

/// Фирменная палитра Almanac.
abstract final class AlmanacBrand {
  /// rgb(158, 202, 255)
  static const Color accentStart = Color(0xFF9ECAFF);

  /// rgb(207, 46, 100)
  static const Color accentEnd = Color(0xFFCF2E64);

  /// Замена тёплого акцента rgb(255, 182, 140) → rgb(130, 28, 63)
  static const Color warmAccent = Color(0xFF821C3F);
  static LinearGradient accentGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [accentStart, accentEnd],
    );
  }

  /// Пресеты акцента для настроек профиля.
  static const List<Color> accentPresets = [
    accentEnd,
    warmAccent,
    Color(0xFF2196F3),
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFFF5722),
  ];

  /// Свободный слот записи на календаре участника.
  static const Color bookingOpen = accentEnd;

  /// Занятый слот записи.
  static const Color bookingFull = Color(0xFF5A6B73);

  /// Контрастный цвет иконки/текста на заливке.
  static Color onFill(Color background) {
    return background.computeLuminance() > 0.55
        ? const Color(0xDE000000)
        : const Color(0xFFFFFFFF);
  }

  static bool isBuiltinPreset(Color color) {
    return accentPresets.any((preset) => preset.toARGB32() == color.toARGB32());
  }

  /// Material seed-blues и старые оттенки Almanac → акцент при отрисовке.
  static const List<Color> _legacyUiBlues = [
    Color(0xFF92BEF2),
    Color(0xFF9ECAFF),
    Color(0xFF92BCEC),
    Color(0xFF95C0F2),
    Color(0xFFA1C0E7),
    Color(0xFF2196F3),
    Color(0xFF42A5F5),
    Color(0xFF64B5F6),
    Color(0xFF90CAF9),
    Color(0xFFBBDEFB),
    accentStart,
  ];
  static bool isLegacyUiBlue(Color color) {
    final argb = color.toARGB32();
    for (final target in _legacyUiBlues) {
      if (target.toARGB32() == argb) return true;
    }
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    if (b < 185 || g < 130 || r > 180) return false;
    for (final target in _legacyUiBlues) {
      final tr = (target.r * 255).round();
      final tg = (target.g * 255).round();
      final tb = (target.b * 255).round();
      final dist =
          (r - tr) * (r - tr) + (g - tg) * (g - tg) + (b - tb) * (b - tb);
      if (dist < 1600) return true;
    }
    return false;
  }

  static Color resolveEventAccentColor(Color color, Color accentEnd) {
    if (!isLegacyUiBlue(color)) return color;
    return accentEnd.withValues(alpha: color.a);
  }
}

/// Цвета подсветки календаря, зависят от акцента активного профиля.
@immutable
class ProfileHighlightColors extends ThemeExtension<ProfileHighlightColors> {
  const ProfileHighlightColors({
    required this.accentStart,
    required this.accentEnd,
    required this.warmAccent,
  });

  final Color accentStart;
  final Color accentEnd;
  final Color warmAccent;
  factory ProfileHighlightColors.fromAccent(Color accent) {
    return ProfileHighlightColors(
      accentStart: Color.lerp(accent, AlmanacBrand.accentStart, 0.58)!,
      accentEnd: accent,
      warmAccent: Color.lerp(accent, AlmanacBrand.warmAccent, 0.62)!,
    );
  }
  LinearGradient accentGradient({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [accentStart, accentEnd],
    );
  }

  /// Перелив вкладки режима: от фона темы к акценту профиля.
  LinearGradient tabSelectionGradient(ColorScheme scheme) {
    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [scheme.surfaceContainerHighest, accentEnd],
    );
  }

  @override
  ProfileHighlightColors copyWith({
    Color? accentStart,
    Color? accentEnd,
    Color? warmAccent,
  }) {
    return ProfileHighlightColors(
      accentStart: accentStart ?? this.accentStart,
      accentEnd: accentEnd ?? this.accentEnd,
      warmAccent: warmAccent ?? this.warmAccent,
    );
  }

  @override
  ProfileHighlightColors lerp(
    ThemeExtension<ProfileHighlightColors>? other,
    double t,
  ) {
    if (other is! ProfileHighlightColors) return this;
    return ProfileHighlightColors(
      accentStart: Color.lerp(accentStart, other.accentStart, t)!,
      accentEnd: Color.lerp(accentEnd, other.accentEnd, t)!,
      warmAccent: Color.lerp(warmAccent, other.warmAccent, t)!,
    );
  }
}

/// Единые отступы приложения.
abstract final class AlmanacSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const EdgeInsets screenPaddingMobile = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: md,
  );
  static const EdgeInsets screenPaddingDesktop = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets sheetPadding = EdgeInsets.all(md);
}

/// Невидимые распорки с шагом [AlmanacSpacing] — переиспользуемые const-виджеты.
abstract final class AlmanacGap {
  static const xxs = SizedBox(
    width: AlmanacSpacing.xxs,
    height: AlmanacSpacing.xxs,
  );
  static const xs = SizedBox(
    width: AlmanacSpacing.xs,
    height: AlmanacSpacing.xs,
  );
  static const sm = SizedBox(
    width: AlmanacSpacing.sm,
    height: AlmanacSpacing.sm,
  );
  static const md = SizedBox(
    width: AlmanacSpacing.md,
    height: AlmanacSpacing.md,
  );
  static const lg = SizedBox(
    width: AlmanacSpacing.lg,
    height: AlmanacSpacing.lg,
  );
}

/// Радиусы скругления.
abstract final class AlmanacRadius {
  static const double xxs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  /// Карточки, панели, списки.
  static const BorderRadius surface = BorderRadius.all(Radius.circular(md));

  /// Кнопки, сегменты, бейджи.
  static const BorderRadius control = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius button = control;
  static const BorderRadius card = surface;
  static const BorderRadius input = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Скругление модальных панелей (верх и низ одинаковые по величине).
  static const double sheet = xl;
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius sheetBottom = BorderRadius.vertical(
    bottom: Radius.circular(sheet),
  );
}

/// Брейкпоинты адаптивности.
abstract final class AlmanacBreakpoints {
  static const double mobile = 600;
  static const double tablet = 960;
  static const double desktop = 1200;
  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
  static int yearViewColumns(double width) {
    if (width < 520) return 2;
    if (width < 820) return 3;
    return 4;
  }
}

/// Размеры интерактивных элементов (мин. 48 dp для удобного нажатия).
abstract final class AlmanacSizes {
  static const double buttonHeight = 48;
  static const double buttonMinWidth = 48;
  static const double iconButton = 48;
  static const double navButtonSize = 44;
  static const double topBarHeight = 56;
  static const double maxContentWidth = AlmanacBreakpoints.tablet;
}

/// Единые размеры полей ввода, выпадающих списков и сегментов.
abstract final class AlmanacFieldLayout {
  static const double height = AlmanacSizes.buttonHeight;
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: AlmanacSpacing.sm,
    vertical: 14,
  );
  static const BorderRadius highlightRadius = AlmanacRadius.control;
}

/// Тени и elevation.
abstract final class AlmanacElevation {
  static const double card = 0;
  static const double button = 0;
  static const double raised = 2;
  static List<BoxShadow> softShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  static List<BoxShadow> subtleShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> selectedShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.primary.withValues(alpha: 0.28),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

/// Длительности анимаций (GPU-friendly: opacity/transform).
abstract final class AlmanacDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration smooth = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  /// База «притяжения» на одну колонку (хватит кадров на 90/120 Hz).
  static const Duration snap = Duration(milliseconds: 340);
}

/// Длительность магнитного snap. Тикер всё равно бьётся в 60–120 Hz.
Duration almanacAttractDuration({
  required double distance,
  double unitExtent = 120,
}) {
  if (unitExtent <= 0 || distance <= 0) {
    return AlmanacDurations.snap;
  }
  final units = (distance / unitExtent).clamp(0.4, 1.8);
  return Duration(
    milliseconds: (AlmanacDurations.snap.inMilliseconds * units).round().clamp(
      260,
      520,
    ),
  );
}

/// Кривые для плавности на 90/120 Hz.
abstract final class AlmanacCurves {
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutQuart;

  /// Магнитное притяжение: быстрый старт и длинное мягкое торможение.
  static const Curve snap = Cubic(0.16, 1.0, 0.3, 1.0);
}

/// Декоративные поверхности и фоны.
abstract final class AlmanacDecor {
  static LinearGradient scaffoldGradient(ColorScheme scheme) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        scheme.surfaceContainerLowest,
        scheme.surface,
        scheme.surfaceContainerLow.withValues(alpha: 0.35),
      ],
      stops: const [0, 0.55, 1],
    );
  }

  static BoxDecoration frostedSurface(
    ColorScheme scheme, {
    BorderRadius? borderRadius,
    bool elevated = true,
    bool bordered = true,
  }) {
    return BoxDecoration(
      color: scheme.surfaceContainerLow.withValues(alpha: 0.92),
      borderRadius: borderRadius ?? AlmanacRadius.card,
      border: bordered
          ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.22))
          : null,
      boxShadow: elevated ? AlmanacElevation.softShadow(scheme) : null,
    );
  }
}

/// Дополнительные семантические цвета поверх ColorScheme.
@immutable
class AlmanacColors extends ThemeExtension<AlmanacColors> {
  const AlmanacColors({
    required this.weekend,
    required this.success,
    required this.danger,
    required this.muted,
  });

  final Color weekend;
  final Color success;
  final Color danger;
  final Color muted;
  static AlmanacColors of(ColorScheme scheme) {
    return AlmanacColors(
      weekend: Color.lerp(scheme.tertiary, scheme.error, 0.35)!,
      success: const Color(0xFF2E7D32),
      danger: scheme.error,
      muted: scheme.onSurfaceVariant.withValues(alpha: 0.78),
    );
  }

  @override
  AlmanacColors copyWith({
    Color? weekend,
    Color? success,
    Color? danger,
    Color? muted,
  }) {
    return AlmanacColors(
      weekend: weekend ?? this.weekend,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      muted: muted ?? this.muted,
    );
  }

  @override
  AlmanacColors lerp(ThemeExtension<AlmanacColors>? other, double t) {
    if (other is! AlmanacColors) return this;
    return AlmanacColors(
      weekend: Color.lerp(weekend, other.weekend, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension AlmanacThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AlmanacColors get almanacColors =>
      Theme.of(this).extension<AlmanacColors>() ?? AlmanacColors.of(colors);
  ProfileHighlightColors get profileHighlight =>
      Theme.of(this).extension<ProfileHighlightColors>() ??
      ProfileHighlightColors.fromAccent(AlmanacBrand.accentEnd);
  EdgeInsets screenPadding(double width) => AlmanacBreakpoints.isMobile(width)
      ? AlmanacSpacing.screenPaddingMobile
      : AlmanacSpacing.screenPaddingDesktop;
}
