import 'calendar_types.dart';

/// Быстрые правки смены без открытия полной формы.
enum ShiftQuickAction { toggleSkip, addOvertime30 }

extension ShiftQuickActionX on ShiftQuickAction {
  static const overtimeStepMinutes = 30;
}

/// Применяет быстрое действие к смене (создаёт override при необходимости).
AppEvent applyShiftQuickActionPatch({
  required AppEvent source,
  required ShiftQuickAction action,
}) {
  switch (action) {
    case ShiftQuickAction.toggleSkip:
      final skipped = !source.shiftSkipped;
      return source.copyWith(
        shiftSkipped: skipped,
        clearOvertimeMinutes: skipped && source.overtimeMinutes != null,
        clearUnpaidMinutes: skipped && source.unpaidMinutes != null,
      );
    case ShiftQuickAction.addOvertime30:
      if (source.shiftSkipped) return source;
      final current = source.overtimeMinutes ?? 0;
      return source.copyWith(
        overtimeMinutes: current + ShiftQuickActionX.overtimeStepMinutes,
      );
  }
}
