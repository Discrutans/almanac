import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Единая карточка Almanac с мягкой тенью и frosted-фоном.
class AlmanacCard extends StatelessWidget {
  const AlmanacCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevated = true,
    this.bordered = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool elevated;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: padding ?? AlmanacSpacing.cardPadding,
      child: child,
    );
    final decoration = AlmanacDecor.frostedSurface(
      scheme,
      elevated: elevated,
      bordered: bordered,
    );
    final body = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: AlmanacRadius.card,
              splashColor: scheme.primary.withValues(alpha: 0.08),
              highlightColor: scheme.primary.withValues(alpha: 0.04),
              child: content,
            ),
          );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: decoration,
        child: ClipRRect(borderRadius: AlmanacRadius.card, child: body),
      ),
    );
  }
}
