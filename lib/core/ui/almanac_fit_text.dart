import 'package:flutter/material.dart';

/// Текст фиксированного кегля, который равномерно сжимается, если не влезает.
///
/// Масштаб считается композицией ([FittedBox]), без пересчёта [TextPainter]
/// в цикле layout — строка не дёргается между кадрами.
class AlmanacFitText extends StatelessWidget {
  const AlmanacFitText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.alignment = Alignment.centerLeft,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    final heightFactor = style.height ?? 1.2;
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(fontSize) *
        heightFactor *
        maxLines;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final bounded = maxWidth.isFinite && maxWidth > 0;
        final child = Text(
          text,
          maxLines: maxLines,
          softWrap: maxLines > 1,
          overflow: bounded ? TextOverflow.visible : TextOverflow.ellipsis,
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: style,
        );
        if (!bounded) {
          return SizedBox(height: lineHeight, child: child);
        }
        return SizedBox(
          width: maxWidth,
          height: lineHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            clipBehavior: Clip.hardEdge,
            child: child,
          ),
        );
      },
    );
  }
}
