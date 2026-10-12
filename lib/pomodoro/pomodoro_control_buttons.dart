import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../state/pomodoro_session_notifier.dart';

/// Кнопки Pomodoro для карточек и полноэкранного таймера.
class PomodoroControlButtons extends ConsumerWidget {
  const PomodoroControlButtons({
    super.key,
    this.compact = false,
    this.weekTile = false,
    this.listTile = false,
    this.sheetControls = false,
    this.enabled = true,
    this.event,
    this.onEventUpdated,
  });

  final bool compact;
  final bool weekTile;
  final bool listTile;

  /// true — три кнопки в полноэкранном таймере; false — ▶/⏸ + ■ на карточках.
  final bool sheetControls;
  final bool enabled;
  final AppEvent? event;
  final ValueChanged<AppEvent>? onEventUpdated;

  void _ensureBound(WidgetRef ref) {
    final boundEvent = event;
    final callback = onEventUpdated;
    if (boundEvent == null || callback == null) return;
    final session = ref.read(pomodoroSessionProvider);
    if (session.matchesEvent(boundEvent.id)) return;
    ref
        .read(pomodoroSessionProvider.notifier)
        .bind(event: boundEvent, onEventUpdated: callback);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(pomodoroSessionProvider);
    final canBind = event != null && onEventUpdated != null;
    if (!session.isActive && !canBind) return const SizedBox.shrink();
    final notifier = ref.read(pomodoroSessionProvider.notifier);
    final boundToThisEvent = session.matchesEvent(
      event?.id ?? session.eventId ?? '',
    );
    final showStop = boundToThisEvent;
    final iconSize = 22.0;
    const buttonSpacing = AlmanacSpacing.xs;
    Widget controlButton({
      required String tooltip,
      required IconData icon,
      required VoidCallback onPressed,
      required bool highlighted,
      Color? color,
    }) {
      final accent = color ?? scheme.primary;
      return Tooltip(
        message: tooltip,
        child: IconButton(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(
            minHeight: AlmanacSizes.buttonHeight,
            minWidth: AlmanacSizes.buttonMinWidth,
          ),
          style: IconButton.styleFrom(
            backgroundColor: highlighted
                ? accent.withValues(alpha: 0.16)
                : scheme.surfaceContainerHighest,
            foregroundColor: highlighted ? accent : scheme.onSurfaceVariant,
            minimumSize: const Size(
              AlmanacSizes.buttonMinWidth,
              AlmanacSizes.buttonHeight,
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
            shape: RoundedRectangleBorder(
              borderRadius: AlmanacRadius.chip,
              side: highlighted
                  ? BorderSide(color: accent.withValues(alpha: 0.55))
                  : BorderSide.none,
            ),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: iconSize),
        ),
      );
    }

    if (sheetControls) {
      final workActive = session.phase == PomodoroPhase.work && session.running;
      final breakActive =
          session.phase == PomodoroPhase.rest && session.running;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          controlButton(
            tooltip: l10n.pomodoroStartWork,
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              _ensureBound(ref);
              notifier.startWork();
            },
            highlighted: workActive,
            color: scheme.primary,
          ),
          SizedBox(width: buttonSpacing),
          controlButton(
            tooltip: l10n.pomodoroStartBreak,
            icon: Icons.pause_rounded,
            onPressed: () {
              _ensureBound(ref);
              notifier.startBreak();
            },
            highlighted: breakActive,
            color: context.profileHighlight.warmAccent,
          ),
          if (showStop) ...[
            SizedBox(width: buttonSpacing),
            controlButton(
              tooltip: l10n.pomodoroEndSession,
              icon: Icons.stop_rounded,
              onPressed: notifier.endSession,
              highlighted: false,
              color: scheme.error,
            ),
          ],
        ],
      );
    }
    final workRunning = session.running && session.phase == PomodoroPhase.work;
    final toggleIcon = workRunning
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
    final toggleTooltip = workRunning
        ? l10n.pomodoroStartBreak
        : l10n.pomodoroStartWork;
    final toggleColor = workRunning
        ? context.profileHighlight.warmAccent
        : scheme.primary;
    final toggle = controlButton(
      tooltip: toggleTooltip,
      icon: toggleIcon,
      onPressed: () {
        _ensureBound(ref);
        notifier.toggleWorkBreak();
      },
      highlighted: session.running,
      color: toggleColor,
    );
    final stop = showStop
        ? controlButton(
            tooltip: l10n.pomodoroEndSession,
            icon: Icons.stop_rounded,
            onPressed: notifier.endSession,
            highlighted: false,
            color: scheme.error,
          )
        : null;

    if (weekTile) {
      return Row(
        children: [
          Expanded(child: toggle),
          if (stop != null) ...[
            SizedBox(width: buttonSpacing),
            Expanded(child: stop),
          ],
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        toggle,
        if (stop != null) ...[SizedBox(width: buttonSpacing), stop],
      ],
    );
  }
}
