import 'calendar_types.dart';
import 'calendar_event_index.dart';
import '../state/calendar_toolbar_providers.dart';
import '../state/calendar_navigation_notifier.dart';

/// Нужна ли кнопка «Сегодня» в toolbar для текущего режима.
bool shouldShowCalendarTodayButton({
  required CalendarMode mode,
  required CalendarNavigationState nav,
  required DateTime today,
  CalendarToolbarViewState? viewState,
}) {
  final todayKey = calendarDayKey(today);

  switch (mode) {
    case CalendarMode.month:
      return nav.focusedMonth.year != todayKey.year ||
          nav.focusedMonth.month != todayKey.month;
    case CalendarMode.year:
      return nav.focusedMonth.year != todayKey.year;
    case CalendarMode.week:
      if (!isTodayInSelectedWeek(nav.selectedDate, todayKey)) {
        return true;
      }
      return viewState?.showToday ?? false;
    case CalendarMode.agenda:
      if (nav.focusedMonth.year != todayKey.year ||
          nav.focusedMonth.month != todayKey.month) {
        return true;
      }
      return viewState?.showToday ?? false;
  }
}

/// true, если [today] попадает в неделю, содержащую [selectedDate].
bool isTodayInSelectedWeek(DateTime selectedDate, DateTime today) {
  final weekStart = calendarWeekStartMonday(selectedDate);
  for (var offset = 0; offset < 7; offset++) {
    final day = weekStart.add(Duration(days: offset));
    if (isSameCalendarDay(day, today)) {
      return true;
    }
  }
  return false;
}
