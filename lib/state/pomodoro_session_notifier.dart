import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_types.dart';

enum PomodoroPhase { work, rest }

@immutable
class PomodoroSessionState {
  const PomodoroSessionState({
    this.eventId,
    this.phase = PomodoroPhase.work,
    this.workRemainingSeconds = 0,
    this.breakRemainingSeconds = 0,
    this.running = false,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.completedSessions = 0,
  });

  static const idle = PomodoroSessionState();

  final String? eventId;
  final PomodoroPhase phase;
  final int workRemainingSeconds;
  final int breakRemainingSeconds;
  final bool running;
  final int workMinutes;
  final int breakMinutes;
  final int completedSessions;

  bool get isActive => eventId != null;

  bool matchesEvent(String id) => eventId == id;

  int get remainingSeconds => phase == PomodoroPhase.work
      ? workRemainingSeconds
      : breakRemainingSeconds;

  int get totalSeconds =>
      phase == PomodoroPhase.work ? workMinutes * 60 : breakMinutes * 60;

  double get progress =>
      totalSeconds <= 0 ? 0 : 1 - (remainingSeconds / totalSeconds);

  PomodoroSessionState copyWith({
    String? eventId,
    PomodoroPhase? phase,
    int? workRemainingSeconds,
    int? breakRemainingSeconds,
    bool? running,
    int? workMinutes,
    int? breakMinutes,
    int? completedSessions,
    bool clearEvent = false,
  }) {
    return PomodoroSessionState(
      eventId: clearEvent ? null : (eventId ?? this.eventId),
      phase: phase ?? this.phase,
      workRemainingSeconds: workRemainingSeconds ?? this.workRemainingSeconds,
      breakRemainingSeconds:
          breakRemainingSeconds ?? this.breakRemainingSeconds,
      running: running ?? this.running,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }
}

String formatPomodoroDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

PomodoroSessionState pomodoroSessionFromEvent(AppEvent event) {
  final workMinutes = event.pomodoroWorkMinutes.clamp(1, 180);

  final breakMinutes = event.pomodoroBreakMinutes.clamp(1, 180);

  final workTotal = workMinutes * 60;
  final breakTotal = breakMinutes * 60;
  final onBreak = event.isPomodoroOnBreak;

  var workRemaining = event.pomodoroWorkRemainingSeconds ?? workTotal;
  var breakRemaining = event.pomodoroBreakRemainingSeconds ?? breakTotal;

  final saved = event.pomodoroRemainingSeconds;
  if (saved != null) {
    if (onBreak) {
      breakRemaining = saved.clamp(1, breakTotal).toInt();
    } else {
      workRemaining = saved.clamp(1, workTotal).toInt();
    }
  }

  workRemaining = workRemaining.clamp(1, workTotal).toInt();
  breakRemaining = breakRemaining.clamp(1, breakTotal).toInt();

  return PomodoroSessionState(
    eventId: event.id,
    phase: onBreak ? PomodoroPhase.rest : PomodoroPhase.work,
    workRemainingSeconds: workRemaining,
    breakRemainingSeconds: breakRemaining,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
    completedSessions: event.pomodoroCompletedSessions,
  );
}

/// Глобальное состояние Pomodoro — таймер виден в списке и неделе.
class PomodoroSessionNotifier extends Notifier<PomodoroSessionState> {
  Timer? _timer;
  AppEvent? _activeEvent;
  void Function(AppEvent event)? _onEventUpdated;

  @override
  PomodoroSessionState build() {
    ref.onDispose(_cancelTimer);
    return PomodoroSessionState.idle;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _persistProgress() {
    final event = _activeEvent;
    final callback = _onEventUpdated;
    if (event == null || callback == null || !state.isActive) return;

    final updated = event.copyWith(
      pomodoroRemainingSeconds: state.remainingSeconds,
      pomodoroOnBreak: state.phase == PomodoroPhase.rest,
      pomodoroWorkRemainingSeconds: state.workRemainingSeconds,
      pomodoroBreakRemainingSeconds: state.breakRemainingSeconds,
      pomodoroCompletedSessions: state.completedSessions,
    );
    _activeEvent = updated;
    callback(updated);
  }

  void _persistFullReset() {
    final event = _activeEvent;
    final callback = _onEventUpdated;
    if (event == null || callback == null || !state.isActive) return;

    final workTotal = state.workMinutes * 60;
    final breakTotal = state.breakMinutes * 60;
    final updated = event.copyWith(
      pomodoroRemainingSeconds: workTotal,
      pomodoroOnBreak: false,
      pomodoroWorkRemainingSeconds: workTotal,
      pomodoroBreakRemainingSeconds: breakTotal,
      pomodoroCompletedSessions: state.completedSessions,
    );
    _activeEvent = updated;
    callback(updated);
  }

  void bind({
    required AppEvent event,
    required void Function(AppEvent event) onEventUpdated,
  }) {
    _onEventUpdated = onEventUpdated;

    if (state.matchesEvent(event.id)) {
      _activeEvent = event;
      return;
    }

    _cancelTimer();
    _activeEvent = event;
    state = pomodoroSessionFromEvent(event);
  }

  /// Одна кнопка на карточках: ▶ работа, ⏸ перерыв (чередуются).
  void toggleWorkBreak() {
    if (!state.isActive) return;
    _cancelTimer();

    if (state.running && state.phase == PomodoroPhase.work) {
      state = state.copyWith(phase: PomodoroPhase.rest, running: true);
    } else {
      state = state.copyWith(phase: PomodoroPhase.work, running: true);
    }

    _startTimer();
  }

  void startWork() {
    if (!state.isActive) return;
    _cancelTimer();
    state = state.copyWith(phase: PomodoroPhase.work, running: true);
    _startTimer();
  }

  /// Перерыв (отдельная кнопка в полноэкранном таймере).
  void startBreak() {
    if (!state.isActive) return;
    _cancelTimer();
    state = state.copyWith(phase: PomodoroPhase.rest, running: true);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.phase == PomodoroPhase.work) {
      if (state.workRemainingSeconds <= 1) {
        _onPhaseFinished();
        return;
      }
      state = state.copyWith(
        workRemainingSeconds: state.workRemainingSeconds - 1,
      );
      return;
    }

    if (state.breakRemainingSeconds <= 1) {
      _onPhaseFinished();
      return;
    }
    state = state.copyWith(
      breakRemainingSeconds: state.breakRemainingSeconds - 1,
    );
  }

  void _onPhaseFinished() {
    _cancelTimer();
    if (state.phase == PomodoroPhase.work) {
      final nextCompleted = state.completedSessions + 1;
      final updated = _activeEvent?.copyWith(
        pomodoroCompletedSessions: nextCompleted,
      );
      if (updated != null) {
        _activeEvent = updated;
        _onEventUpdated?.call(updated);
      }
      state = state.copyWith(completedSessions: nextCompleted);
      startBreak();
      return;
    }
    _finishBreakPhase();
  }

  void _finishBreakPhase() {
    _cancelTimer();
    state = state.copyWith(
      phase: PomodoroPhase.work,
      running: false,
      breakRemainingSeconds: state.breakMinutes * 60,
    );
    _persistProgress();
  }

  /// Полная остановка сессии (иконка «стоп» — квадрат).
  void endSession() {
    _cancelTimer();
    if (!state.isActive) return;

    final workTotal = state.workMinutes * 60;
    final breakTotal = state.breakMinutes * 60;
    state = state.copyWith(
      phase: PomodoroPhase.work,
      running: false,
      workRemainingSeconds: workTotal,
      breakRemainingSeconds: breakTotal,
    );
    _persistFullReset();
  }
}

final pomodoroSessionProvider =
    NotifierProvider<PomodoroSessionNotifier, PomodoroSessionState>(
      PomodoroSessionNotifier.new,
    );
