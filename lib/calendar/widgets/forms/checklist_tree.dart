import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_tappable.dart';
import '../../calendar_types.dart';

/// Элемент плоского списка дерева чек-листа.
class ChecklistTreeEntry {
  const ChecklistTreeEntry({
    required this.item,
    required this.depth,
    required this.isLast,
    required this.ancestorContinues,
    this.parentTitle,
  });

  final ChecklistItem item;
  final int depth;
  final bool isLast;
  final List<bool> ancestorContinues;
  final String? parentTitle;
}

List<ChecklistTreeEntry> flattenChecklistTree(
  List<ChecklistItem> items, {
  int depth = 0,
  List<bool> ancestorContinues = const [],
  String? parentTitle,
}) {
  final result = <ChecklistTreeEntry>[];
  for (var index = 0; index < items.length; index++) {
    final item = items[index];
    final isLast = index == items.length - 1;
    result.add(
      ChecklistTreeEntry(
        item: item,
        depth: depth,
        isLast: isLast,
        ancestorContinues: ancestorContinues,
        parentTitle: parentTitle,
      ),
    );
    result.addAll(
      flattenChecklistTree(
        item.children,
        depth: depth + 1,
        ancestorContinues: [...ancestorContinues, !isLast],
        parentTitle: item.title,
      ),
    );
  }
  return result;
}

/// Визуальные линии дерева слева от задачи.
class ChecklistTreeIndent extends StatelessWidget {
  const ChecklistTreeIndent({
    super.key,
    required this.depth,
    required this.isLast,
    required this.ancestorContinues,
    this.compact = false,
  });

  final int depth;
  final bool isLast;
  final List<bool> ancestorContinues;
  final bool compact;

  static const double _step = 18;
  static const double _compactStep = 12;

  @override
  Widget build(BuildContext context) {
    if (depth == 0) {
      return SizedBox(width: compact ? 0 : AlmanacSpacing.xxs);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = colorScheme.outlineVariant;
    final step = compact ? _compactStep : _step;

    return SizedBox(
      width: depth * step + (compact ? 2 : 4),
      height: compact ? AlmanacSizes.buttonHeight : 40,
      child: CustomPaint(
        painter: _ChecklistTreePainter(
          depth: depth,
          isLast: isLast,
          ancestorContinues: ancestorContinues,
          lineColor: lineColor,
          nodeColor: colorScheme.primary.withValues(alpha: 0.55),
          step: step,
        ),
      ),
    );
  }
}

class _ChecklistTreePainter extends CustomPainter {
  _ChecklistTreePainter({
    required this.depth,
    required this.isLast,
    required this.ancestorContinues,
    required this.lineColor,
    required this.nodeColor,
    required this.step,
  });

  final int depth;
  final bool isLast;
  final List<bool> ancestorContinues;
  final Color lineColor;
  final Color nodeColor;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final vertical = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final branch = Paint()
      ..color = nodeColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var level = 0; level < depth - 1; level++) {
      if (level < ancestorContinues.length && ancestorContinues[level]) {
        final x = step * (level + 0.5);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), vertical);
      }
    }

    final branchX = step * (depth - 0.5);
    final midY = size.height / 2;
    canvas.drawLine(
      Offset(branchX, 0),
      Offset(branchX, isLast ? midY : size.height),
      vertical,
    );
    canvas.drawLine(
      Offset(branchX, midY),
      Offset(size.width - 2, midY),
      branch,
    );
  }

  @override
  bool shouldRepaint(covariant _ChecklistTreePainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.isLast != isLast ||
        oldDelegate.lineColor != lineColor;
  }
}

/// Компактная полоска прогресса чек-листа для agenda/списка.
class CompactChecklistProgress extends StatelessWidget {
  const CompactChecklistProgress({
    super.key,
    required this.completed,
    required this.total,
    required this.color,
    required this.label,
  });

  final int completed;
  final int total;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : completed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: AlmanacRadius.chip,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Строка чек-листа в списке/agenda — скруглённый квадрат в стиле приложения.
class ChecklistListItemTile extends StatelessWidget {
  const ChecklistListItemTile({
    super.key,
    required this.entry,
    required this.onToggle,
    this.accentColor,
    this.compact = false,
  });

  final ChecklistTreeEntry entry;
  final ValueChanged<bool> onToggle;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? colorScheme.primary;
    final isRoot = entry.depth == 0;

    if (compact) {
      return AlmanacTappable(
        onTap: () => onToggle(!item.completed),
        borderRadius: AlmanacRadius.control,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChecklistTreeIndent(
              depth: entry.depth,
              isLast: entry.isLast,
              ancestorContinues: entry.ancestorContinues,
              compact: true,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IgnorePointer(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    value: item.completed,
                    activeColor: accent,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.25,
                  decoration: item.completed
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.completed
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
      child: AlmanacTappable(
        onTap: () => onToggle(!item.completed),
        color: isRoot
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: AlmanacRadius.control,
        padding: const EdgeInsets.symmetric(
          horizontal: AlmanacSpacing.xs,
          vertical: AlmanacSpacing.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChecklistTreeIndent(
              depth: entry.depth,
              isLast: entry.isLast,
              ancestorContinues: entry.ancestorContinues,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AlmanacRadius.control,
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              child: IgnorePointer(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    value: item.completed,
                    activeColor: accent,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
            const SizedBox(width: AlmanacSpacing.xs),
            Expanded(
              child: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  decoration: item.completed
                      ? TextDecoration.lineThrough
                      : null,
                  color: item.completed
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
