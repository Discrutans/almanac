part of '../week_view.dart';



class _WeekEventsPanel extends StatefulWidget {

  const _WeekEventsPanel({

    required this.height,

    required this.weekDates,

    required this.eventsIndex,

    required this.selectedDate,

    required this.activeProfileId,

    required this.colorFilter,

    required this.profileSeedColors,

    required this.profileNamesById,

    required this.onEditEvent,

    required this.onEventUpdated,

    this.onShiftQuickAction,

    this.onEventMoved,

    this.onEventResized,

    this.onRefresh,

    this.hideEmptyWeekHours = false,

    this.weekHourPaddingBefore = 2,

    this.weekHourPaddingAfter = 1,

    this.weekHourZoomLevel = kWeekHourZoomLevelDefault,

    this.onWeekHourZoomLevelChanged,

    this.dragSession = WeekDragSession.empty,

    this.onEmptySlotTap,

    this.selectedSlot,

    this.onSelectedSlotChanged,

    this.gridKey,

    this.move,

    this.onMoveResult,

    this.forceFullHourAxis = false,

  });



  final double height;

  final List<DateTime> weekDates;

  final Map<DateTime, List<AppEvent>> eventsIndex;

  final DateTime selectedDate;

  final String activeProfileId;

  final Set<int> colorFilter;

  final Map<String, Color> profileSeedColors;

  final Map<String, String> profileNamesById;

  final ValueChanged<AppEvent> onEditEvent;

  final ValueChanged<AppEvent> onEventUpdated;

  final ShiftQuickActionCallback? onShiftQuickAction;

  final WeekEventMoveCallback? onEventMoved;

  final WeekEventResizeCallback? onEventResized;

  final Future<void> Function()? onRefresh;

  final bool hideEmptyWeekHours;

  final int weekHourPaddingBefore;

  final int weekHourPaddingAfter;

  final int weekHourZoomLevel;

  final ValueChanged<int>? onWeekHourZoomLevelChanged;

  final WeekDragSession dragSession;

  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;

  final WeekGridSlot? selectedSlot;

  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;

  final GlobalKey<WeekEventsDropGridState>? gridKey;

  final WeekMoveController? move;

  final ValueChanged<WeekMoveResult>? onMoveResult;

  final bool forceFullHourAxis;



  @override

  State<_WeekEventsPanel> createState() => _WeekEventsPanelState();

}



class _WeekEventsPanelState extends State<_WeekEventsPanel> {

  @override

  Widget build(BuildContext context) {

    return AlmanacCard(

      padding: const EdgeInsets.symmetric(horizontal: AlmanacSpacing.xs),

      child: RefreshIndicator(

        onRefresh: widget.onRefresh ?? () async {},

        child: SizedBox(

          height: widget.height,

          child: WeekEventsDropGrid(

            key: widget.gridKey,

            weekDates: widget.weekDates,

            eventsIndex: widget.eventsIndex,

            selectedDate: widget.selectedDate,

            activeProfileId: widget.activeProfileId,

            colorFilter: widget.colorFilter,

            profileSeedColors: widget.profileSeedColors,

            profileNamesById: widget.profileNamesById,

            onEditEvent: widget.onEditEvent,

            onEventUpdated: widget.onEventUpdated,

            onShiftQuickAction: widget.onShiftQuickAction,

            onEventMoved: widget.onEventMoved,

            onEventResized: widget.onEventResized,

            hideEmptyWeekHours: widget.hideEmptyWeekHours,

            weekHourPaddingBefore: widget.weekHourPaddingBefore,

            weekHourPaddingAfter: widget.weekHourPaddingAfter,

            weekHourZoomLevel: widget.weekHourZoomLevel,

            onWeekHourZoomLevelChanged: widget.onWeekHourZoomLevelChanged,

            dragSession: widget.dragSession,

            onEmptySlotTap: widget.onEmptySlotTap,

            selectedSlot: widget.selectedSlot,

            onSelectedSlotChanged: widget.onSelectedSlotChanged,

            move: widget.move,

            onMoveResult: widget.onMoveResult,

            forceFullHourAxis: widget.forceFullHourAxis,

          ),

        ),

      ),

    );

  }

}

