import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_types.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_fit_text.dart';
import '../state/pomodoro_session_notifier.dart';
import 'pomodoro_control_buttons.dart';
import 'pomodoro_timer_sheet.dart';

/// Высота иконки события в списке — ориентир для панели Pomodoro.
const double kPomodoroListPanelHeight = 40;

/// Компактный индикатор активного Pomodoro для карточки события.
class PomodoroLiveIndicator extends ConsumerWidget {
  const PomodoroLiveIndicator({
    super.key,
    required this.event,
    this.onEventUpdated,
    this.compact = false,
    this.expandToWidth = false,
  });

  final AppEvent event;
  final ValueChanged<AppEvent>? onEventUpdated;
  final bool compact;
  final bool expandToWidth;

  IconData _statusIcon({required bool running, required bool workPhase}) {
    if (!running) return Icons.timer_outlined;
    return workPhase ? Icons.play_arrow_rounded : Icons.pause_rounded;
  }

  void _openSheet(BuildContext context, WidgetRef ref) {
    if (onEventUpdated == null) return;
    ref
        .read(pomodoroSessionProvider.notifier)
        .bind(event: event, onEventUpdated: onEventUpdated!);
    PomodoroTimerSheet.show(
      context,
      event: event,
      onEventUpdated: onEventUpdated!,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!event.hasPomodoro) {
      return const SizedBox.shrink();
    }
    final session = ref.watch(pomodoroSessionProvider);
    if (session.matchesEvent(event.id)) {
      return _buildLivePanel(context, ref, session);
    }
    return _buildIdlePanel(context, ref);
  }

  Widget _buildIdlePanel(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final snapshot = pomodoroSessionFromEvent(event);
    final accent = snapshot.phase == PomodoroPhase.work
        ? scheme.primary
        : context.profileHighlight.warmAccent;
    final time = formatPomodoroDuration(snapshot.remainingSeconds);
    final phaseLabel = snapshot.phase == PomodoroPhase.work
        ? l10n.pomodoroPhaseWork
        : l10n.pomodoroPhaseBreak;
    return _buildPanelShell(
      context: context,
      ref: ref,
      tooltip: l10n.pomodoroOpenTimer,
      accent: accent,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: AlmanacRadius.chip,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      time: time,
      phaseLabel: phaseLabel,
      running: false,
      workPhase: snapshot.phase == PomodoroPhase.work,
    );
  }

  Widget _buildLivePanel(
    BuildContext context,
    WidgetRef ref,
    PomodoroSessionState session,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final phaseLabel = session.phase == PomodoroPhase.work
        ? l10n.pomodoroPhaseWork
        : l10n.pomodoroPhaseBreak;
    final accent = session.phase == PomodoroPhase.work
        ? scheme.primary
        : context.profileHighlight.warmAccent;
    final time = formatPomodoroDuration(session.remainingSeconds);
    final tooltip = session.running
        ? l10n.pomodoroLiveRunning(time, phaseLabel)
        : l10n.pomodoroLivePaused(time, phaseLabel);
    return _buildPanelShell(
      context: context,
      ref: ref,
      tooltip: tooltip,
      accent: accent,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: session.running ? 0.16 : 0.1),
        borderRadius: AlmanacRadius.chip,
        border: Border.all(
          color: accent.withValues(alpha: session.running ? 0.85 : 0.45),
          width: session.running ? 1.5 : 1,
        ),
      ),
      time: time,
      phaseLabel: phaseLabel,
      running: session.running,
      workPhase: session.phase == PomodoroPhase.work,
    );
  }

  Widget _buildPanelShell({
    required BuildContext context,
    required WidgetRef ref,
    required String tooltip,
    required Color accent,
    required BoxDecoration decoration,
    required String time,
    required String phaseLabel,
    required bool running,
    required bool workPhase,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final weekTile = compact && expandToWidth;
    final listTile = expandToWidth && !compact;
    final onOpenSheet = onEventUpdated == null
        ? null
        : () => _openSheet(context, ref);
    final controls = onEventUpdated == null
        ? null
        : PomodoroControlButtons(
            compact: true,
            weekTile: weekTile,
            listTile: listTile,
            event: event,
            onEventUpdated: onEventUpdated,
          );
    final Widget panelBody;
    if (weekTile) {
      panelBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWeekTimeBlock(
            context: context,
            accent: accent,
            scheme: scheme,
            time: time,
            phaseLabel: phaseLabel,
            running: running,
            workPhase: workPhase,
            onOpenSheet: onOpenSheet,
          ),
          if (controls != null) ...[const SizedBox(height: 6), controls],
        ],
      );
    } else {
      panelBody = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildHorizontalTimeBlock(
              context: context,
              accent: accent,
              scheme: scheme,
              time: time,
              phaseLabel: phaseLabel,
              running: running,
              workPhase: workPhase,
              listTile: listTile,
              showPhaseLabel: !compact || listTile,
              onOpenSheet: onOpenSheet,
            ),
          ),
          ?controls,
        ],
      );
    }
    return Tooltip(
      message: tooltip,
      child: Container(
        width: expandToWidth ? double.infinity : null,
        constraints: listTile
            ? const BoxConstraints(minHeight: kPomodoroListPanelHeight)
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: weekTile
              ? AlmanacSpacing.xs
              : (listTile ? AlmanacSpacing.sm : AlmanacSpacing.xxs),
          vertical: weekTile
              ? AlmanacSpacing.xs
              : (listTile ? 6 : AlmanacSpacing.xxs),
        ),
        decoration: decoration,
        child: panelBody,
      ),
    );
  }

  Widget _buildWeekTimeBlock({
    required BuildContext context,
    required Color accent,
    required ColorScheme scheme,
    required String time,
    required String phaseLabel,
    required bool running,
    required bool workPhase,
    VoidCallback? onOpenSheet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSheet,
        borderRadius: AlmanacRadius.chip,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _statusIcon(running: running, workPhase: workPhase),
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: AlmanacFitText(
                      text: time,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontSize: 16,
                            height: 1.1,
                          ) ??
                          TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontSize: 16,
                            height: 1.1,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              AlmanacFitText(
                text: phaseLabel,
                style:
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.15,
                    ) ??
                    TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.15,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalTimeBlock({
    required BuildContext context,
    required Color accent,
    required ColorScheme scheme,
    required String time,
    required String phaseLabel,
    required bool running,
    required bool workPhase,
    required bool listTile,
    required bool showPhaseLabel,
    VoidCallback? onOpenSheet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSheet,
        borderRadius: AlmanacRadius.chip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AlmanacSizes.buttonHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  _statusIcon(running: running, workPhase: workPhase),
                  size: listTile ? 18 : (compact ? 13 : 16),
                  color: accent,
                ),
                SizedBox(
                  width: listTile ? AlmanacSpacing.xs : AlmanacSpacing.xxs,
                ),
                Flexible(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: listTile ? 14 : (compact ? 11 : null),
                    ),
                  ),
                ),
                if (showPhaseLabel) ...[
                  SizedBox(
                    width: listTile ? AlmanacSpacing.xs : AlmanacSpacing.xxs,
                  ),
                  Flexible(
                    child: Text(
                      phaseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: listTile ? 12 : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
