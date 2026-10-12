import 'package:flutter/material.dart';
import 'almanac_tokens.dart';

TextTheme _buildTextTheme(TextTheme base, ColorScheme colorScheme) {
  TextStyle? tune(TextStyle? style, {FontWeight? weight, double? spacing}) {
    return style?.copyWith(
      fontWeight: weight ?? style.fontWeight,
      letterSpacing: spacing ?? style.letterSpacing,
      color: style.color ?? colorScheme.onSurface,
    );
  }

  return base.copyWith(
    titleLarge: tune(base.titleLarge, weight: FontWeight.w700, spacing: -0.4),
    titleMedium: tune(base.titleMedium, weight: FontWeight.w700, spacing: -0.2),
    titleSmall: tune(base.titleSmall, weight: FontWeight.w600),
    labelLarge: tune(base.labelLarge, weight: FontWeight.w600, spacing: 0.1),
    labelMedium: tune(base.labelMedium, weight: FontWeight.w600),
    labelSmall: tune(base.labelSmall, weight: FontWeight.w500, spacing: 0.2),
    bodyMedium: tune(base.bodyMedium),
    bodySmall: tune(base.bodySmall, spacing: 0.1),
  );
}

/// Собирает единую Material 3 тему Almanac.

ThemeData buildAlmanacTheme({
  required Color seedColor,
  required Brightness brightness,
  Color accentColor = AlmanacBrand.accentEnd,
}) {
  final highlightColors = ProfileHighlightColors.fromAccent(accentColor);

  final seedScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  final colorScheme = seedScheme.copyWith(
    primary: accentColor,
    onPrimary: Colors.white,
    primaryContainer: highlightColors.accentStart,
    onPrimaryContainer: accentColor,
    secondary: highlightColors.accentEnd,
    onSecondary: Colors.white,
    secondaryContainer: highlightColors.accentEnd,
    onSecondaryContainer: Colors.white,
    tertiary: highlightColors.warmAccent,
    onTertiary: Colors.white,
    tertiaryContainer: highlightColors.warmAccent.withValues(alpha: 0.24),
    onTertiaryContainer: highlightColors.warmAccent,
  );

  final almanacColors = AlmanacColors.of(colorScheme);

  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    extensions: [almanacColors, highlightColors],
  );

  final textTheme = _buildTextTheme(base.textTheme, colorScheme);
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    cardTheme: CardThemeData(
      elevation: AlmanacElevation.card,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.94),
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: AlmanacRadius.card,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant.withValues(alpha: 0.22),
      space: 1,
      thickness: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      borderRadius: AlmanacRadius.chip,
      color: accentColor,
      linearTrackColor: colorScheme.surfaceContainerHighest,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(
          AlmanacSizes.iconButton,
          AlmanacSizes.iconButton,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          AlmanacSizes.buttonMinWidth,
          AlmanacSizes.buttonHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.md),
        elevation: AlmanacElevation.raised,
        shadowColor: colorScheme.primary.withValues(alpha: 0.25),
        shape: const RoundedRectangleBorder(borderRadius: AlmanacRadius.button),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          AlmanacSizes.buttonMinWidth,
          AlmanacSizes.buttonHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.md),
        shape: const RoundedRectangleBorder(borderRadius: AlmanacRadius.button),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          AlmanacSizes.buttonMinWidth,
          AlmanacSizes.buttonHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.sm),
        shape: const RoundedRectangleBorder(borderRadius: AlmanacRadius.button),
        foregroundColor: accentColor,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AlmanacRadius.input),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AlmanacSpacing.sm),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          if (states.contains(WidgetState.disabled)) return null;
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.38);
          }
          return colorScheme.onSurface;
        }),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: false,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      contentPadding: AlmanacFieldLayout.contentPadding,
      border: OutlineInputBorder(
        borderRadius: AlmanacRadius.input,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AlmanacRadius.input,
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AlmanacRadius.input,
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AlmanacRadius.input,
        borderSide: BorderSide(color: colorScheme.error),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: AlmanacFieldLayout.highlightRadius,
      ),
      minVerticalPadding: AlmanacSpacing.xs,
      horizontalTitleGap: AlmanacSpacing.sm,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlmanacRadius.xxs),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: AlmanacRadius.chip),
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: AlmanacRadius.card),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AlmanacRadius.card),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AlmanacRadius.card),
        ),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlmanacRadius.sheet),
      ),
      hourMinuteShape: const RoundedRectangleBorder(
        borderRadius: AlmanacRadius.input,
      ),
      dayPeriodShape: const RoundedRectangleBorder(
        borderRadius: AlmanacRadius.control,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlmanacRadius.sheet),
      ),
      dayShape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AlmanacRadius.control),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: AlmanacElevation.raised,
      shape: RoundedRectangleBorder(borderRadius: AlmanacRadius.input),
    ),
    dialogTheme: DialogThemeData(
      elevation: AlmanacElevation.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AlmanacRadius.sheet),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AlmanacSpacing.md,
        vertical: AlmanacSpacing.lg,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: false,
      elevation: AlmanacElevation.raised,
      backgroundColor: colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(borderRadius: AlmanacRadius.sheetTop),
    ),
    focusColor: colorScheme.primary.withValues(alpha: 0.12),
    hoverColor: colorScheme.primary.withValues(alpha: 0.08),
    highlightColor: colorScheme.primary.withValues(alpha: 0.1),
  );
}
