import 'package:flutter/material.dart';
import '../theme/almanac_tokens.dart';

/// Крупная кнопка-стрелка для навигации по периодам.
class AlmanacNavButton extends StatefulWidget {
  const AlmanacNavButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<AlmanacNavButton> createState() => _AlmanacNavButtonState();
}

class _AlmanacNavButtonState extends State<AlmanacNavButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final button = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: AlmanacDurations.instant,
        curve: AlmanacCurves.enter,
        child: AnimatedContainer(
          duration: AlmanacDurations.fast,
          width: AlmanacSizes.navButtonSize,
          height: AlmanacSizes.navButtonSize,
          decoration: BoxDecoration(
            color: enabled
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.85)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: AlmanacRadius.control,
            boxShadow: enabled
                ? AlmanacElevation.subtleShadow(colorScheme)
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 24,
            color: enabled
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.tooltip,
      child: widget.tooltip == null
          ? button
          : Tooltip(message: widget.tooltip!, child: button),
    );
  }
}

/// Иконка 48×48 с тактильным scale.
class AlmanacIconButton extends StatefulWidget {
  const AlmanacIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<AlmanacIconButton> createState() => _AlmanacIconButtonState();
}

class _AlmanacIconButtonState extends State<AlmanacIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null;
    final button = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1,
        duration: AlmanacDurations.instant,
        child: AnimatedContainer(
          duration: AlmanacDurations.fast,
          width: AlmanacSizes.navButtonSize,
          height: AlmanacSizes.navButtonSize,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: enabled ? 0.1 : 0.05),
            borderRadius: AlmanacRadius.control,
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}

/// Компактная pill-кнопка «Сегодня» и подобные.
class AlmanacPillButton extends StatelessWidget {
  const AlmanacPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AlmanacRadius.pill,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.25)!,
              ],
            ),
            borderRadius: AlmanacRadius.pill,
            boxShadow: AlmanacElevation.selectedShadow(colorScheme),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AlmanacSpacing.md,
              vertical: AlmanacSpacing.xs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: colorScheme.onPrimary),
                  const SizedBox(width: AlmanacSpacing.xxs),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
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

/// Кнопка сохранения с индикатором загрузки для диалогов.
class AlmanacAsyncFilledButton extends StatelessWidget {
  const AlmanacAsyncFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}

/// Горизонтальный ряд action-кнопок для диалогов.
class AlmanacDialogActions extends StatelessWidget {
  const AlmanacDialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AlmanacSpacing.xs,
      runSpacing: AlmanacSpacing.xs,
      children: children,
    );
  }
}
