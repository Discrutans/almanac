import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Полноширинный сегментный переключатель со скруглённым выделением.
class AlmanacSegmentedBar<T> extends StatelessWidget {
  const AlmanacSegmentedBar({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
    this.enabled = true,
    this.height = AlmanacFieldLayout.height,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = context.profileHighlight;
    final selectedIndex = values.indexOf(selected).clamp(0, values.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final segmentWidth = width / values.length;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: AlmanacRadius.input,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: ClipRRect(
            borderRadius: AlmanacRadius.input,
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _SlidingHighlight(
                      left: selectedIndex * segmentWidth,
                      width: segmentWidth,
                      height: height,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: highlight.accentEnd,
                            borderRadius: AlmanacFieldLayout.highlightRadius,
                            boxShadow: [
                              BoxShadow(
                                color: highlight.accentEnd.withValues(
                                  alpha: 0.28,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final item in values)
                          Expanded(
                            child: _Segment(
                              selected: item == selected,
                              enabled: enabled,
                              label: labelOf(item),
                              icon: iconOf?.call(item),
                              onTap: () => onChanged(item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Подсветка сегмента через композицию (Translate), без перекладки Stack.
class _SlidingHighlight extends StatefulWidget {
  const _SlidingHighlight({
    required this.left,
    required this.width,
    required this.height,
    required this.child,
  });

  final double left;
  final double width;
  final double height;
  final Widget child;

  @override
  State<_SlidingHighlight> createState() => _SlidingHighlightState();
}

class _SlidingHighlightState extends State<_SlidingHighlight> {
  late double _visualLeft = widget.left;

  @override
  void didUpdateWidget(covariant _SlidingHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width) {
      _visualLeft = widget.left;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _visualLeft, end: widget.left),
      duration: AlmanacDurations.smooth,
      curve: AlmanacCurves.emphasis,
      builder: (context, value, child) {
        _visualLeft = value;
        return Transform.translate(
          offset: Offset(value, 0),
          transformHitTests: false,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final bool selected;
  final bool enabled;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final highlight = context.profileHighlight;
    final color = selected
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled || selected ? null : onTap,
        borderRadius: AlmanacRadius.input,
        splashColor: highlight.accentStart.withValues(alpha: 0.12),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: AlmanacDurations.fast,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
