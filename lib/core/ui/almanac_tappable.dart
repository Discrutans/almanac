import 'package:flutter/material.dart';

import '../theme/almanac_tokens.dart';

/// Кликабельная зона на карточке: минимум 48 dp и непрозрачный hit-test,
/// чтобы родительский InkWell / drag не перехватывали нажатие.
class AlmanacTappable extends StatelessWidget {
  const AlmanacTappable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.color,
    this.minHeight = AlmanacSizes.buttonHeight,
    this.padding,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? color;
  final double minHeight;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AlmanacRadius.chip;
    return Material(
      color: color ?? Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight,
            minWidth: AlmanacSizes.buttonMinWidth,
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}
