import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../state/pomodoro_session_notifier.dart';
import 'pomodoro_control_buttons.dart';

/// Полноэкранный Pomodoro-таймер, привязанный к событию.
class PomodoroTimerSheet extends ConsumerStatefulWidget {
  const PomodoroTimerSheet({
    super.key,
    required this.event,
    required this.onEventUpdated,
  });

  final AppEvent event;
  final ValueChanged<AppEvent> onEventUpdated;

  static Future<void> show(
    BuildContext context, {
    required AppEvent event,
    required ValueChanged<AppEvent> onEventUpdated,
  }) {
    return showAlmanacSheet<void>(
      context: context,
      title: event.title,
      size: AlmanacPanelSize.hug,
      compactWidth: true,
      child: PomodoroTimerSheet(event: event, onEventUpdated: onEventUpdated),
    );
  }

  @override
  ConsumerState<PomodoroTimerSheet> createState() => _PomodoroTimerSheetState();
}

class _PomodoroTimerSheetState extends ConsumerState<PomodoroTimerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(pomodoroSessionProvider.notifier)
          .bind(event: widget.event, onEventUpdated: widget.onEventUpdated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(pomodoroSessionProvider);

    if (!session.matchesEvent(widget.event.id)) {
      return const SizedBox.shrink();
    }

    final progress = session.progress;
    final phaseLabel = session.phase == PomodoroPhase.work
        ? l10n.pomodoroPhaseWork
        : l10n.pomodoroPhaseBreak;
    final accent = session.phase == PomodoroPhase.work
        ? scheme.primary
        : context.profileHighlight.warmAccent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          phaseLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                color: accent,
                backgroundColor: accent.withValues(alpha: 0.15),
              ),
              Text(
                formatPomodoroDuration(session.remainingSeconds),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AlmanacSpacing.sm),
        Text(
          l10n.pomodoroSessionsLine(session.completedSessions),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AlmanacSpacing.md),
        PomodoroControlButtons(
          compact: false,
          sheetControls: true,
          event: widget.event,
          onEventUpdated: widget.onEventUpdated,
        ),
      ],
    );
  }
}
