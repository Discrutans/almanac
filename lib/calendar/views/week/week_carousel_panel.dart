part of '../week_view.dart';



class _WeekCarouselPanel extends StatelessWidget {

  const _WeekCarouselPanel({

    required this.height,

    required this.columnWidth,

    required this.viewportWidth,

    required this.laneDates,

    required this.selectedDate,

    required this.eventsIndex,

    required this.activeProfileId,

    required this.colorFilter,

    required this.profileSeedColors,

    required this.profileNamesById,

    required this.onDateSelected,

    required this.onDateLongPress,

    required this.onEditEvent,

    required this.onEventUpdated,

    this.onShiftQuickAction,

    required this.onEventMoved,

    this.onEventResized,

    required this.scrollController,

    required this.viewportKey,

    this.move,

    this.onMoveResult,

    this.onScrollNotification,

    required this.scrollLocked,

    this.hideEmptyWeekHours = false,

    this.weekHourPaddingBefore = 2,

    this.weekHourPaddingAfter = 1,

    this.weekHourZoomLevel = kWeekHourZoomLevelDefault,

    this.onWeekHourZoomLevelChanged,

    this.forceFullHourAxis = false,

    this.dragSession = WeekDragSession.empty,

    this.onEmptySlotTap,

    this.selectedSlot,

    this.onSelectedSlotChanged,

  });



  final double height;

  final double columnWidth;

  final double viewportWidth;

  final List<DateTime> laneDates;

  final DateTime selectedDate;

  final Map<DateTime, List<AppEvent>> eventsIndex;

  final String activeProfileId;

  final Set<int> colorFilter;

  final Map<String, Color> profileSeedColors;

  final Map<String, String> profileNamesById;

  final ValueChanged<DateTime> onDateSelected;

  final ValueChanged<DateTime>? onDateLongPress;

  final ValueChanged<AppEvent> onEditEvent;

  final ValueChanged<AppEvent> onEventUpdated;

  final ShiftQuickActionCallback? onShiftQuickAction;

  final WeekEventMoveCallback? onEventMoved;

  final WeekEventResizeCallback? onEventResized;

  final ScrollController scrollController;

  final GlobalKey<WeekCarouselUnifiedState> viewportKey;

  final WeekMoveController? move;

  final ValueChanged<WeekMoveResult>? onMoveResult;

  final NotificationListenerCallback<ScrollNotification>? onScrollNotification;

  final bool scrollLocked;

  final bool hideEmptyWeekHours;

  final int weekHourPaddingBefore;

  final int weekHourPaddingAfter;

  final int weekHourZoomLevel;

  final ValueChanged<int>? onWeekHourZoomLevelChanged;

  final bool forceFullHourAxis;

  final WeekDragSession dragSession;

  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;

  final WeekGridSlot? selectedSlot;

  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;



  @override

  Widget build(BuildContext context) {

    return AlmanacCard(

      padding: _WeekCalendarViewState._carouselCardPadding,

      child: WeekCarouselUnified(

        key: viewportKey,

        height: height,

        columnWidth: columnWidth,

        viewportWidth: viewportWidth,

        laneDates: laneDates,

        selectedDate: selectedDate,

        eventsIndex: eventsIndex,

        activeProfileId: activeProfileId,

        onDateSelected: onDateSelected,

        onDateLongPress: onDateLongPress,

        onEditEvent: onEditEvent,

        onEventUpdated: onEventUpdated,

        onShiftQuickAction: onShiftQuickAction,

        colorFilter: colorFilter,

        profileSeedColors: profileSeedColors,

        profileNamesById: profileNamesById,

        onEventMoved: onEventMoved,

        onEventResized: onEventResized,

        move: move,

        onMoveResult: onMoveResult,

        onScrollNotification: onScrollNotification,

        controller: scrollController,

        scrollLocked: scrollLocked,

        hideEmptyWeekHours: hideEmptyWeekHours,

        weekHourPaddingBefore: weekHourPaddingBefore,

        weekHourPaddingAfter: weekHourPaddingAfter,

        weekHourZoomLevel: weekHourZoomLevel,

        onWeekHourZoomLevelChanged: onWeekHourZoomLevelChanged,

        forceFullHourAxis: forceFullHourAxis,

        dragSession: dragSession,

        onEmptySlotTap: onEmptySlotTap,

        selectedSlot: selectedSlot,

        onSelectedSlotChanged: onSelectedSlotChanged,

      ),

    );

  }

}

