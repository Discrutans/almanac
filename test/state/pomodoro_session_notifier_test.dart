import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/state/pomodoro_session_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kalender/kalender.dart';

void main() {
  AppEvent sampleEvent() {
    return AppEvent(
      id: 'e1',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 7, 24, 9),
        end: DateTime(2026, 7, 24, 10),
      ),
      title: 'Focus',
      startTime: '09:00',
      endTime: '10:00',
      color: const Color(0xFF0000FF),
      pomodoroEnabled: true,
      pomodoroWorkMinutes: 25,
      pomodoroBreakMinutes: 5,
      interaction: EventInteraction.allowNone(),
    );
  }

  test('bind starts a work session for event', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(pomodoroSessionProvider.notifier)
        .bind(event: sampleEvent(), onEventUpdated: (_) {});
    final session = container.read(pomodoroSessionProvider);
    expect(session.eventId, 'e1');
    expect(session.phase, PomodoroPhase.work);
    expect(session.remainingSeconds, 25 * 60);
    expect(session.running, isFalse);
  });
  test('startWork runs work phase timer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroSessionProvider.notifier);
    notifier.bind(event: sampleEvent(), onEventUpdated: (_) {});
    notifier.startWork();
    final session = container.read(pomodoroSessionProvider);
    expect(session.phase, PomodoroPhase.work);
    expect(session.running, isTrue);
  });
  test('startBreak switches to rest phase timer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroSessionProvider.notifier);
    notifier.bind(event: sampleEvent(), onEventUpdated: (_) {});
    notifier.startBreak();
    final session = container.read(pomodoroSessionProvider);
    expect(session.phase, PomodoroPhase.rest);
    expect(session.remainingSeconds, 5 * 60);
    expect(session.running, isTrue);
  });
  test('toggle preserves work remaining when switching phases', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroSessionProvider.notifier);
    notifier.bind(
      event: sampleEvent().copyWith(pomodoroWorkRemainingSeconds: 20 * 60),
      onEventUpdated: (_) {},
    );
    notifier.toggleWorkBreak();
    expect(container.read(pomodoroSessionProvider).phase, PomodoroPhase.work);
    expect(
      container.read(pomodoroSessionProvider).workRemainingSeconds,
      20 * 60,
    );
    notifier.toggleWorkBreak();
    expect(container.read(pomodoroSessionProvider).phase, PomodoroPhase.rest);
    expect(container.read(pomodoroSessionProvider).running, isTrue);
    notifier.toggleWorkBreak();
    final session = container.read(pomodoroSessionProvider);
    expect(session.phase, PomodoroPhase.work);
    expect(session.workRemainingSeconds, 20 * 60);
    expect(session.running, isTrue);
  });
  test('bind for same event does not reset active session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(pomodoroSessionProvider.notifier);
    notifier.bind(
      event: sampleEvent().copyWith(pomodoroWorkRemainingSeconds: 18 * 60),
      onEventUpdated: (_) {},
    );
    notifier.startWork();
    notifier.bind(event: sampleEvent(), onEventUpdated: (_) {});
    final session = container.read(pomodoroSessionProvider);
    expect(session.running, isTrue);
    expect(session.workRemainingSeconds, 18 * 60);
  });
  test('endSession fully resets timer to defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    AppEvent? saved;
    final notifier = container.read(pomodoroSessionProvider.notifier);
    notifier.bind(
      event: sampleEvent().copyWith(
        pomodoroWorkRemainingSeconds: 24 * 60 + 50,
        pomodoroBreakRemainingSeconds: 4 * 60,
        pomodoroOnBreak: true,
      ),
      onEventUpdated: (event) => saved = event,
    );
    notifier.startWork();
    notifier.endSession();
    final session = container.read(pomodoroSessionProvider);
    expect(session.running, isFalse);
    expect(session.phase, PomodoroPhase.work);
    expect(session.workRemainingSeconds, 25 * 60);
    expect(session.breakRemainingSeconds, 5 * 60);
    expect(saved?.pomodoroWorkRemainingSeconds, 25 * 60);
    expect(saved?.pomodoroBreakRemainingSeconds, 5 * 60);
    expect(saved?.pomodoroOnBreak, isNot(true));
    expect(saved?.pomodoroRemainingSeconds, 25 * 60);
  });
  test('formatPomodoroDuration renders mm:ss', () {
    expect(formatPomodoroDuration(125), '02:05');
  });
}
