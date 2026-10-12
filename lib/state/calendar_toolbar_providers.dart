import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Состояние активного вида календаря для [CalendarToolbar].
@immutable
class CalendarToolbarViewState {
  const CalendarToolbarViewState({this.showToday = false});

  /// Показывать «Сегодня» (неделя / список — вычисляется во view).
  final bool showToday;

  bool matchesToolbarContent(CalendarToolbarViewState? other) {
    if (other == null) return false;
    return showToday == other.showToday;
  }
}

final calendarToolbarViewStateProvider =
    StateProvider<CalendarToolbarViewState?>((ref) => null);

void publishCalendarToolbarViewState(
  WidgetRef ref,
  CalendarToolbarViewState? next,
) {
  final current = ref.read(calendarToolbarViewStateProvider);
  if (next == null) {
    if (current != null) {
      ref.read(calendarToolbarViewStateProvider.notifier).state = null;
    }
    return;
  }
  if (current != null && current.matchesToolbarContent(next)) return;
  ref.read(calendarToolbarViewStateProvider.notifier).state = next;
}

void clearCalendarToolbarViewStateFromRef(Ref ref) {
  ref.read(calendarToolbarViewStateProvider.notifier).state = null;
}
