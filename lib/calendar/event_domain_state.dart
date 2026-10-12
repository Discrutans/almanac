import 'note_attachment.dart';

/// Pomodoro-состояние, привязанное к [AppEvent].
final class EventPomodoroState {
  const EventPomodoroState({
    this.enabled = false,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.completedSessions = 0,
    this.remainingSeconds,
    this.onBreak,
    this.workRemainingSeconds,
    this.breakRemainingSeconds,
  });

  static const EventPomodoroState disabled = EventPomodoroState();

  final bool enabled;
  final int workMinutes;
  final int breakMinutes;
  final int completedSessions;
  final int? remainingSeconds;
  final bool? onBreak;
  final int? workRemainingSeconds;
  final int? breakRemainingSeconds;

  bool get hasActiveTimer =>
      enabled &&
      (remainingSeconds != null ||
          workRemainingSeconds != null ||
          breakRemainingSeconds != null);

  bool get isOnBreak => onBreak ?? false;

  EventPomodoroState copyWith({
    bool? enabled,
    int? workMinutes,
    int? breakMinutes,
    int? completedSessions,
    int? remainingSeconds,
    bool? onBreak,
    int? workRemainingSeconds,
    int? breakRemainingSeconds,
    bool clearRemainingSeconds = false,
    bool clearWorkRemainingSeconds = false,
    bool clearBreakRemainingSeconds = false,
  }) {
    return EventPomodoroState(
      enabled: enabled ?? this.enabled,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      completedSessions: completedSessions ?? this.completedSessions,
      remainingSeconds: clearRemainingSeconds
          ? null
          : (remainingSeconds ?? this.remainingSeconds),
      onBreak: onBreak ?? this.onBreak,
      workRemainingSeconds: clearWorkRemainingSeconds
          ? null
          : (workRemainingSeconds ?? this.workRemainingSeconds),
      breakRemainingSeconds: clearBreakRemainingSeconds
          ? null
          : (breakRemainingSeconds ?? this.breakRemainingSeconds),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventPomodoroState &&
        other.enabled == enabled &&
        other.workMinutes == workMinutes &&
        other.breakMinutes == breakMinutes &&
        other.completedSessions == completedSessions &&
        other.remainingSeconds == remainingSeconds &&
        other.onBreak == onBreak &&
        other.workRemainingSeconds == workRemainingSeconds &&
        other.breakRemainingSeconds == breakRemainingSeconds;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    workMinutes,
    breakMinutes,
    completedSessions,
    remainingSeconds,
    onBreak,
    workRemainingSeconds,
    breakRemainingSeconds,
  );
}

/// Финансы записи: доход и подарок.
final class EventFinanceState {
  const EventFinanceState({this.incomeAmount, this.isGift = false});

  static const EventFinanceState empty = EventFinanceState();

  final double? incomeAmount;
  final bool isGift;

  bool get hasFinanceMarker => incomeAmount != null && incomeAmount! > 0;

  EventFinanceState copyWith({
    double? incomeAmount,
    bool? isGift,
    bool clearIncomeAmount = false,
  }) {
    return EventFinanceState(
      incomeAmount: clearIncomeAmount
          ? null
          : (incomeAmount ?? this.incomeAmount),
      isGift: isGift ?? this.isGift,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventFinanceState &&
        other.incomeAmount == incomeAmount &&
        other.isGift == isGift;
  }

  @override
  int get hashCode => Object.hash(incomeAmount, isGift);
}

/// Корректировки оплаты смены (work schedule).
final class EventShiftPayState {
  const EventShiftPayState({
    this.overtimeMinutes,
    this.shiftSkipped = false,
    this.unpaidMinutes,
  });

  static const EventShiftPayState none = EventShiftPayState();

  final int? overtimeMinutes;
  final bool shiftSkipped;
  final int? unpaidMinutes;

  EventShiftPayState copyWith({
    int? overtimeMinutes,
    bool? shiftSkipped,
    int? unpaidMinutes,
    bool clearOvertimeMinutes = false,
    bool clearUnpaidMinutes = false,
  }) {
    return EventShiftPayState(
      overtimeMinutes: clearOvertimeMinutes
          ? null
          : (overtimeMinutes ?? this.overtimeMinutes),
      shiftSkipped: shiftSkipped ?? this.shiftSkipped,
      unpaidMinutes: clearUnpaidMinutes
          ? null
          : (unpaidMinutes ?? this.unpaidMinutes),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EventShiftPayState &&
        other.overtimeMinutes == overtimeMinutes &&
        other.shiftSkipped == shiftSkipped &&
        other.unpaidMinutes == unpaidMinutes;
  }

  @override
  int get hashCode => Object.hash(overtimeMinutes, shiftSkipped, unpaidMinutes);
}

/// Вложения заметки (обёртка для единообразия домена).
final class EventAttachmentsState {
  const EventAttachmentsState([this.items = const []]);

  static const EventAttachmentsState empty = EventAttachmentsState();

  final List<NoteAttachment> items;

  bool get isNotEmpty => items.isNotEmpty;
  bool get isEmpty => items.isEmpty;
  int get imageCount => items.where((a) => a.isImage).length;

  EventAttachmentsState copyWith({List<NoteAttachment>? items}) {
    return EventAttachmentsState(items ?? this.items);
  }

  @override
  bool operator ==(Object other) {
    return other is EventAttachmentsState && other.items == items;
  }

  @override
  int get hashCode => items.hashCode;
}
