import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_scroll.dart';

/// Оттенок в палитре Almanac.
@immutable
class AlmanacColorShade {
  const AlmanacColorShade(this.color, this.label);

  final Color color;
  final String label;
}

/// Семейство цветов (hue) с набором оттенков.
@immutable
class AlmanacColorFamily {
  const AlmanacColorFamily({required this.preview, required this.shades});

  final Color preview;
  final List<AlmanacColorShade> shades;
}

/// Компактный color picker в стиле Almanac: скруглённые квадраты, без MaterialPicker.
class AlmanacMiniColorPicker extends StatefulWidget {
  const AlmanacMiniColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<AlmanacMiniColorPicker> createState() => _AlmanacMiniColorPickerState();
}

class _AlmanacMiniColorPickerState extends State<AlmanacMiniColorPicker> {
  static final _families = _buildFamilies();

  late int _familyIndex;

  @override
  void initState() {
    super.initState();
    _familyIndex = _familyIndexForColor(widget.color);
  }

  @override
  void didUpdateWidget(covariant AlmanacMiniColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color.toARGB32() != widget.color.toARGB32()) {
      _familyIndex = _familyIndexForColor(widget.color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = AlmanacBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );
    final family = _families[_familyIndex];
    final selectedArgb = widget.color.toARGB32();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AlmanacRadius.control,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AlmanacSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                cacheExtent: AlmanacScroll.listCacheExtent,
                itemCount: _families.length,
                separatorBuilder: (_, index) =>
                    const SizedBox(width: AlmanacSpacing.xxs),
                itemBuilder: (context, index) {
                  final item = _families[index];
                  final active = index == _familyIndex;
                  return _FamilyChip(
                    color: item.preview,
                    active: active,
                    onTap: () {
                      setState(() => _familyIndex = index);
                      final match = _matchingShade(item, selectedArgb);
                      if (match == null) {
                        widget.onChanged(_defaultShade(item).color);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                cacheExtent: AlmanacScroll.listCacheExtent,
                itemCount: family.shades.length,
                separatorBuilder: (_, index) =>
                    const SizedBox(width: AlmanacSpacing.xxs),
                itemBuilder: (context, index) {
                  final shade = family.shades[index];
                  final selected = shade.color.toARGB32() == selectedArgb;
                  return _ShadeTile(
                    shade: shade,
                    selected: selected,
                    showLabel: isMobile,
                    onTap: () => widget.onChanged(shade.color),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<AlmanacColorFamily> _buildFamilies() {
    List<AlmanacColorShade> shades(MaterialColor color, List<int> stops) {
      return stops
          .map((stop) => AlmanacColorShade(color[stop]!, '$stop'))
          .toList(growable: false);
    }

    List<AlmanacColorShade> accentShades(MaterialAccentColor color) {
      const stops = [100, 200, 400, 700];
      return stops
          .map((stop) => AlmanacColorShade(color[stop]!, '$stop'))
          .toList(growable: false);
    }

    const stops = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900];

    return [
      AlmanacColorFamily(
        preview: Colors.red.shade500,
        shades: shades(Colors.red, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.redAccent.shade400,
        shades: accentShades(Colors.redAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.pink.shade500,
        shades: shades(Colors.pink, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.pinkAccent.shade400,
        shades: accentShades(Colors.pinkAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.purple.shade500,
        shades: shades(Colors.purple, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.purpleAccent.shade400,
        shades: accentShades(Colors.purpleAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.deepPurple.shade500,
        shades: shades(Colors.deepPurple, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.deepPurpleAccent.shade400,
        shades: accentShades(Colors.deepPurpleAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.indigo.shade500,
        shades: shades(Colors.indigo, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.indigoAccent.shade400,
        shades: accentShades(Colors.indigoAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.blue.shade500,
        shades: shades(Colors.blue, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.blueAccent.shade400,
        shades: accentShades(Colors.blueAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.lightBlue.shade500,
        shades: shades(Colors.lightBlue, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.lightBlueAccent.shade400,
        shades: accentShades(Colors.lightBlueAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.cyan.shade500,
        shades: shades(Colors.cyan, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.cyanAccent.shade400,
        shades: accentShades(Colors.cyanAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.teal.shade500,
        shades: shades(Colors.teal, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.tealAccent.shade400,
        shades: accentShades(Colors.tealAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.green.shade500,
        shades: shades(Colors.green, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.greenAccent.shade400,
        shades: accentShades(Colors.greenAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.lightGreen.shade500,
        shades: shades(Colors.lightGreen, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.lightGreenAccent.shade400,
        shades: accentShades(Colors.lightGreenAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.lime.shade500,
        shades: shades(Colors.lime, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.limeAccent.shade400,
        shades: accentShades(Colors.limeAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.yellow.shade700,
        shades: shades(Colors.yellow, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.amber.shade600,
        shades: shades(Colors.amber, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.amberAccent.shade400,
        shades: accentShades(Colors.amberAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.orange.shade500,
        shades: shades(Colors.orange, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.orangeAccent.shade400,
        shades: accentShades(Colors.orangeAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.deepOrange.shade500,
        shades: shades(Colors.deepOrange, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.deepOrangeAccent.shade400,
        shades: accentShades(Colors.deepOrangeAccent),
      ),
      AlmanacColorFamily(
        preview: Colors.brown.shade500,
        shades: shades(Colors.brown, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.blueGrey.shade500,
        shades: shades(Colors.blueGrey, stops),
      ),
      AlmanacColorFamily(
        preview: Colors.grey.shade500,
        shades: [50, 200, 400, 600, 800]
            .map((stop) => AlmanacColorShade(Colors.grey[stop]!, '$stop'))
            .toList(growable: false),
      ),
      AlmanacColorFamily(
        preview: Colors.black,
        shades: const [
          AlmanacColorShade(Colors.black, 'K'),
          AlmanacColorShade(Colors.white, 'W'),
        ],
      ),
    ];
  }

  static AlmanacColorShade _defaultShade(AlmanacColorFamily family) {
    for (final shade in family.shades) {
      if (shade.label == '500') return shade;
    }
    return family.shades[family.shades.length ~/ 2];
  }

  static int _familyIndexForColor(Color color) {
    final argb = color.toARGB32();
    for (var i = 0; i < _families.length; i++) {
      if (_matchingShade(_families[i], argb) != null) return i;
    }

    var bestIndex = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < _families.length; i++) {
      final distance = _colorDistance(color, _families[i].preview);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  static AlmanacColorShade? _matchingShade(
    AlmanacColorFamily family,
    int argb,
  ) {
    for (final shade in family.shades) {
      if (shade.color.toARGB32() == argb) return shade;
    }
    return null;
  }

  static double _colorDistance(Color a, Color b) {
    final ar = a.r * 255, ag = a.g * 255, ab = a.b * 255;
    final br = b.r * 255, bg = b.g * 255, bb = b.b * 255;
    return (ar - br) * (ar - br) +
        (ag - bg) * (ag - bg) +
        (ab - bb) * (ab - bb);
  }
}

class _FamilyChip extends StatelessWidget {
  const _FamilyChip({
    required this.color,
    required this.active,
    required this.onTap,
  });

  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: color,
      borderRadius: AlmanacRadius.control,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AlmanacRadius.control,
        child: AnimatedContainer(
          duration: AlmanacDurations.fast,
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: AlmanacRadius.control,
            border: Border.all(
              color: active
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.35),
              width: active ? 2 : 1,
            ),
          ),
          child: active
              ? Icon(Icons.check_rounded, size: 14, color: _foregroundOn(color))
              : null,
        ),
      ),
    );
  }
}

class _ShadeTile extends StatelessWidget {
  const _ShadeTile({
    required this.shade,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final AlmanacColorShade shade;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = _foregroundOn(shade.color);

    return Material(
      color: shade.color,
      borderRadius: AlmanacRadius.control,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AlmanacRadius.control,
        child: AnimatedContainer(
          duration: AlmanacDurations.fast,
          width: showLabel ? 46 : 34,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AlmanacRadius.control,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.28),
              width: selected ? 2 : 1,
            ),
          ),
          child: showLabel
              ? Text(
                  shade.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    height: 1,
                  ),
                )
              : selected
              ? Icon(Icons.check_rounded, size: 16, color: fg)
              : null,
        ),
      ),
    );
  }
}

Color _foregroundOn(Color background) {
  final luminance = background.computeLuminance();
  return luminance > 0.55 ? Colors.black87 : Colors.white;
}
