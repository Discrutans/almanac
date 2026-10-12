import 'calendar_types.dart';

/// Разрешённые действия над записью — единая точка вместо разрозненных `if`.
class EntryCapabilities {
  const EntryCapabilities({
    required this.source,
    required this.isPersisted,
    required this.isEphemeralView,
    required this.canDelete,
    required this.canSwipeDelete,
    required this.canRevertOverride,
    required this.canDragInWeekView,
    required this.canUnlockForWeekMove,
    required this.canChangeKind,
    required this.canSetRecurrence,
    required this.canSetPomodoro,
    required this.editsCreateScheduleOverride,
    required this.showDeleteInEditor,
  });

  final CalendarEntrySource source;
  final bool isPersisted;
  final bool isEphemeralView;
  final bool canDelete;
  final bool canSwipeDelete;
  final bool canRevertOverride;

  /// Сразу тащится на сетке: личное без серии и цель накопления.
  final bool canDragInWeekView;

  /// Замок, можно разблокировать long-press (смена, серия, бронь).
  final bool canUnlockForWeekMove;
  final bool canChangeKind;
  final bool canSetRecurrence;
  final bool canSetPomodoro;
  final bool editsCreateScheduleOverride;
  final bool showDeleteInEditor;

  /// Immediate drag: personal/savings. Booking is unlockable even if
  /// [canDragInWeekView] stays true for agenda move-to-date.
  bool get weekDragImmediate => canDragInWeekView && !canUnlockForWeekMove;

  bool get canMoveOnWeekGrid => canDragInWeekView || canUnlockForWeekMove;

  bool get showsWeekLock => !weekDragImmediate;

  static EntryCapabilities forEvent(AppEvent event) {
    final source = event.entrySource;
    final isPersisted = source.isPersisted && !event.isRecurrenceOccurrence;
    final isEphemeralView =
        source.isEphemeralView || event.isRecurrenceOccurrence;

    switch (source) {
      case CalendarEntrySource.personal:
        final series = event.hasRecurrence || event.isRecurrenceOccurrence;
        return EntryCapabilities(
          source: source,
          isPersisted: isPersisted,
          isEphemeralView: isEphemeralView,
          canDelete: !event.isRecurrenceOccurrence,
          canSwipeDelete: !event.isRecurrenceOccurrence,
          canRevertOverride: false,
          canDragInWeekView: !series,
          canUnlockForWeekMove: series,
          canChangeKind: true,
          canSetRecurrence: true,
          canSetPomodoro: true,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: !event.isRecurrenceOccurrence,
        );
      case CalendarEntrySource.booking:
        return EntryCapabilities(
          source: source,
          isPersisted: isPersisted,
          isEphemeralView: isEphemeralView,
          canDelete: !event.isRecurrenceOccurrence,
          canSwipeDelete: !event.isRecurrenceOccurrence,
          canRevertOverride: false,
          canDragInWeekView:
              !event.hasRecurrence && !event.isRecurrenceOccurrence,
          canUnlockForWeekMove: true,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: true,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: !event.isRecurrenceOccurrence,
        );
      case CalendarEntrySource.bookingSlot:
        return const EntryCapabilities(
          source: CalendarEntrySource.bookingSlot,
          isPersisted: false,
          isEphemeralView: true,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: false,
          canDragInWeekView: false,
          canUnlockForWeekMove: false,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: false,
        );
      case CalendarEntrySource.bookingOffer:
        return const EntryCapabilities(
          source: CalendarEntrySource.bookingOffer,
          isPersisted: true,
          isEphemeralView: false,
          canDelete: true,
          canSwipeDelete: true,
          canRevertOverride: false,
          canDragInWeekView: false,
          canUnlockForWeekMove: false,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: true,
        );
      case CalendarEntrySource.bookingPending:
        return const EntryCapabilities(
          source: CalendarEntrySource.bookingPending,
          isPersisted: false,
          isEphemeralView: true,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: false,
          canDragInWeekView: false,
          canUnlockForWeekMove: false,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: false,
        );
      case CalendarEntrySource.scheduleGenerated:
        return EntryCapabilities(
          source: source,
          isPersisted: false,
          isEphemeralView: true,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: false,
          canDragInWeekView: false,
          canUnlockForWeekMove: true,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: true,
          showDeleteInEditor: false,
        );
      case CalendarEntrySource.scheduleOverride:
        return const EntryCapabilities(
          source: CalendarEntrySource.scheduleOverride,
          isPersisted: true,
          isEphemeralView: false,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: true,
          canDragInWeekView: false,
          canUnlockForWeekMove: true,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: true,
          showDeleteInEditor: false,
        );
      case CalendarEntrySource.savingsGoalProjected:
        return const EntryCapabilities(
          source: CalendarEntrySource.savingsGoalProjected,
          isPersisted: false,
          isEphemeralView: true,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: false,
          canDragInWeekView: true,
          canUnlockForWeekMove: false,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: false,
        );
      case CalendarEntrySource.guestCalendar:
        return const EntryCapabilities(
          source: CalendarEntrySource.guestCalendar,
          isPersisted: false,
          isEphemeralView: true,
          canDelete: false,
          canSwipeDelete: false,
          canRevertOverride: false,
          canDragInWeekView: false,
          canUnlockForWeekMove: false,
          canChangeKind: false,
          canSetRecurrence: false,
          canSetPomodoro: false,
          editsCreateScheduleOverride: false,
          showDeleteInEditor: false,
        );
    }
  }
}

extension AppEventEntryCapabilities on AppEvent {
  EntryCapabilities get capabilities => EntryCapabilities.forEvent(this);

  /// Мастер-запись в локальном хранилище (не view-only occurrence).
  bool get isPersistedMaster => capabilities.isPersisted;

  /// Запись только для отображения; сохранять через специализированный API.
  bool get isEphemeralCalendarView => capabilities.isEphemeralView;
}

/// Результат попытки удалить запись через единый API.
enum DeleteEntryResult {
  deleted,
  blockedSchedule,
  blockedNeedsRevert,
  cancelled,
}
