part of 'calendar_screen.dart';

/// Ключ для [AnimatedSwitcher]: меняется при смене режима, но не при смене
/// дня/недели внутри недельного вида (иначе сбрасывается карусель).
String _calendarActiveViewKey({
  required CalendarNavigationState nav,
  required String activeProfileId,
  required Set<String> visibleProfileIds,
}) {
  final profiles = '$activeProfileId-${visibleProfileIds.join(',')}';
  switch (nav.mode) {
    case CalendarMode.month:
      return 'month-${nav.focusedMonth.year}-${nav.focusedMonth.month}-$profiles';
    case CalendarMode.week:
      return 'week-$profiles';
    case CalendarMode.agenda:
      return 'agenda-${nav.focusedMonth.year}-${nav.focusedMonth.month}-$profiles';
    case CalendarMode.year:
      return 'year-${nav.focusedMonth.year}-$profiles';
  }
}

class _CalendarActiveView extends StatelessWidget {
  const _CalendarActiveView({
    super.key,
    required this.mode,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.activeProfileId,
    required this.schedules,
    required this.colorFilter,
    required this.profileNamesById,
    required this.profileSeedColors,
    required this.onDateSelected,
    this.onSelectedDateInWeekChanged,
    this.onDateLongPress,
    required this.onMonthSelected,
    required this.onEditEvent,
    required this.onViewEvent,
    required this.onDeleteEvent,
    required this.onCreateEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    required this.onRefresh,
    this.onWeekEventMoved,
    this.onWeekEventResized,
    this.onMoveEventToDate,
    required this.showSwipeHint,
    required this.onSwipeHintDismissed,
    this.showWeekDragHint = false,
    this.onWeekDragHintDismissed,
    required this.scrollToTodayNonce,
    this.hideEmptyWeekHours = false,
    this.weekHourPaddingBefore = 2,
    this.weekHourPaddingAfter = 1,
    this.weekHourZoomLevel = kWeekHourZoomLevelDefault,
    this.onWeekHourZoomLevelChanged,
    this.lockedByOtherEventIds = const {},
    this.selectedSlot,
    this.onSelectedSlotChanged,
  });

  final CalendarMode mode;
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<AppEvent> events;
  final String activeProfileId;
  final List<CyclicWorkSchedule> schedules;
  final Set<int> colorFilter;
  final Map<String, String> profileNamesById;
  final Map<String, Color> profileSeedColors;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onSelectedDateInWeekChanged;
  final ValueChanged<DateTime>? onDateLongPress;
  final ValueChanged<DateTime> onMonthSelected;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent> onViewEvent;
  final EventDeleteCallback onDeleteEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final Future<void> Function() onRefresh;
  final WeekEventMoveCallback? onWeekEventMoved;
  final WeekEventResizeCallback? onWeekEventResized;
  final EventMoveToDateCallback? onMoveEventToDate;
  final bool showSwipeHint;
  final VoidCallback onSwipeHintDismissed;
  final bool showWeekDragHint;
  final VoidCallback? onWeekDragHintDismissed;
  final int scrollToTodayNonce;
  final bool hideEmptyWeekHours;
  final int weekHourPaddingBefore;
  final int weekHourPaddingAfter;
  final int weekHourZoomLevel;
  final ValueChanged<int>? onWeekHourZoomLevelChanged;
  final Set<String> lockedByOtherEventIds;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CalendarMode.month:
        return MonthCalendarView(
          focusedMonth: focusedMonth,
          selectedDate: selectedDate,
          events: events,
          activeProfileId: activeProfileId,
          schedules: schedules,
          colorFilter: colorFilter,
          onDateSelected: onDateSelected,
          onDateLongPress: onDateLongPress,
        );
      case CalendarMode.week:
        return WeekCalendarView(
          focusedMonth: focusedMonth,
          selectedDate: selectedDate,
          events: events,
          activeProfileId: activeProfileId,
          colorFilter: colorFilter,
          profileSeedColors: profileSeedColors,
          profileNamesById: profileNamesById,
          onDateSelected: onDateSelected,
          onSelectedDateInWeekChanged: onSelectedDateInWeekChanged,
          onDateLongPress: onDateLongPress,
          onEditEvent: onViewEvent,
          onDeleteEvent: onDeleteEvent,
          onCreateEvent: onCreateEvent,
          onEventUpdated: onEventUpdated,
          onShiftQuickAction: onShiftQuickAction,
          onEventMoved: onWeekEventMoved,
          onEventResized: onWeekEventResized,
          onRefresh: onRefresh,
          showWeekDragHint: showWeekDragHint,
          onWeekDragHintDismissed: onWeekDragHintDismissed,
          scrollToTodayNonce: scrollToTodayNonce,
          hideEmptyWeekHours: hideEmptyWeekHours,
          weekHourPaddingBefore: weekHourPaddingBefore,
          weekHourPaddingAfter: weekHourPaddingAfter,
          weekHourZoomLevel: weekHourZoomLevel,
          onWeekHourZoomLevelChanged: onWeekHourZoomLevelChanged,
          lockedByOtherEventIds: lockedByOtherEventIds,
          selectedSlot: selectedSlot,
          onSelectedSlotChanged: onSelectedSlotChanged,
        );
      case CalendarMode.agenda:
        return AgendaCalendarView(
          focusedMonth: focusedMonth,
          selectedDate: selectedDate,
          events: events,
          activeProfileId: activeProfileId,
          colorFilter: colorFilter,
          profileNamesById: profileNamesById,
          profileSeedColors: profileSeedColors,
          onDateSelected: onDateSelected,
          onDateLongPress: onDateLongPress,
          onEditEvent: onViewEvent,
          onViewEvent: onViewEvent,
          onDeleteEvent: onDeleteEvent,
          onCreateEvent: onCreateEvent,
          onEventUpdated: onEventUpdated,
          onShiftQuickAction: onShiftQuickAction,
          onMoveToDate: onMoveEventToDate,
          scrollToTodayNonce: scrollToTodayNonce,
        );
      case CalendarMode.year:
        return YearCalendarView(
          focusedMonth: focusedMonth,
          events: events,
          activeProfileId: activeProfileId,
          colorFilter: colorFilter,
          onMonthSelected: onMonthSelected,
        );
    }
  }
}
