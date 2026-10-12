import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Контрастный цвет текста/иконки на цветном фоне.
Color almanacForegroundOn(Color background) {
  return background.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
}

/// Скруглённый квадратный бейдж цвета в стиле Almanac.
class AlmanacColorBadge extends StatelessWidget {
  const AlmanacColorBadge({
    super.key,
    required this.color,
    this.size = AlmanacAvatarSize.md,
    this.child,
    this.borderColor,
    this.borderWidth = 0,
  });

  final Color color;
  final double size;
  final Widget? child;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: AlmanacRadius.control,
        border: borderWidth > 0
            ? Border.all(
                color:
                    borderColor ?? Theme.of(context).colorScheme.outlineVariant,
                width: borderWidth,
              )
            : null,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

/// Аватар профиля: цвет seed, буква имени или звезда для активного.
class AlmanacProfileAvatar extends StatelessWidget {
  const AlmanacProfileAvatar({
    super.key,
    required this.name,
    required this.seedColor,
    this.isActive = false,
    this.size = AlmanacAvatarSize.md,
  });

  final String name;
  final Color seedColor;
  final bool isActive;
  final double size;

  static String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final highlight = context.profileHighlight;
    final fg = almanacForegroundOn(isActive ? highlight.accentEnd : seedColor);
    final iconSize = size * 0.5;
    final fontSize = size * 0.46;
    final background = isActive ? highlight.accentEnd : seedColor;

    return AlmanacColorBadge(
      color: background,
      size: size,
      borderColor: isActive ? highlight.accentStart : null,
      borderWidth: isActive ? 2 : 0,
      child: isActive
          ? Icon(Icons.star_rounded, size: iconSize, color: fg)
          : Text(
              _initial(name),
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
    );
  }
}

/// Стандартные размеры аватаров Almanac.
abstract final class AlmanacAvatarSize {
  static const double sm = 24;
  static const double md = 28;
  static const double lg = 40;
}
