import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../state/calendar_filter_providers.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';

/// Всплывающая панель фильтра по цвету: квадраты цветов + очистка.
class EventColorFilterPopup extends ConsumerWidget {
  const EventColorFilterPopup({
    super.key,
    required this.events,
    required this.onClose,
  });

  final List<AppEvent> events;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = collectEventColorValues(events);
    if (colors.length <= 1) return const SizedBox.shrink();
    final filter = ref.watch(eventColorFilterProvider);
    return Padding(
      padding: const EdgeInsets.all(AlmanacSpacing.sm),
      child: Wrap(
        spacing: AlmanacSpacing.xxs,
        runSpacing: AlmanacSpacing.xxs,
        children: [
          for (final value in colors)
            _ColorFilterSwatch(
              color: Color(value),
              selected: filter.contains(value),
              onTap: () => toggleEventColorFilter(ref, value),
            ),
          _ClearFilterButton(
            tooltip: l10n.colorFilterReset,
            enabled: filter.isNotEmpty,
            onPressed: () {
              clearEventColorFilter(ref);
              onClose();
            },
          ),
        ],
      ),
    );
  }
}

class _ColorFilterSwatch extends StatelessWidget {
  const _ColorFilterSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AlmanacRadius.control,
      child: AnimatedContainer(
        duration: AlmanacDurations.fast,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: AlmanacRadius.control,
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.35),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)]
              : null,
        ),
        child: selected
            ? Icon(Icons.check, size: 16, color: _checkColor(color))
            : null,
      ),
    );
  }

  static Color _checkColor(Color background) {
    return background.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
  }
}

class _ClearFilterButton extends StatelessWidget {
  const _ClearFilterButton({
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: tooltip,
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled
            ? scheme.errorContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AlmanacRadius.control,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: AlmanacRadius.control,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: enabled
                  ? scheme.error
                  : scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
