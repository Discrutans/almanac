import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../../../core/ui/almanac_scroll.dart';
import '../chrome/calendar_day_badge.dart';
import '../chrome/date_cell.dart';
import '../schedule_quick_actions_bar.dart';
import 'week_axis_viewport_pin.dart';
import 'week_carousel_drag_autoscroll.dart';
import 'week_carousel_snap_physics.dart';
import 'week_day_column.dart';
import 'week_drag_policy.dart';
import 'week_drop_hit_test.dart';
import 'week_events_drop_grid.dart';
import 'week_hour_axis.dart';
import 'week_hour_grid.dart';
import 'week_hour_layout.dart';
import 'week_grid_slot.dart';
import 'week_move_controller.dart';
import 'week_move_types.dart';
import 'week_pinch_hour_controller.dart';
import 'week_timed_drag_layer.dart';
import 'week_ui_tokens.dart';

/// Одна горизонтальная карусель: дата и события дня в одной колонке.
class WeekCarouselUnified extends StatefulWidget {
  const WeekCarouselUnified({
    super.key,
    required this.height,
    required this.columnWidth,
    required this.viewportWidth,
    required this.laneDates,
    required this.selectedDate,
    required this.eventsIndex,
    required this.activeProfileId,
    required this.onDateSelected,
    required this.onEditEvent,
    this.onDateLongPress,
    this.onEventUpdated,
    this.onShiftQuickAction,
    this.colorFilter = const {},
    this.profileSeedColors = const {},
    this.profileNamesById = const {},
    this.onEventMoved,
    this.onEventResized,
    this.move,
    this.onMoveResult,
    this.onScrollNotification,
    this.controller,
    this.scrollLocked = false,
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
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final Set<int> colorFilter;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final WeekEventMoveCallback? onEventMoved;
  final WeekEventResizeCallback? onEventResized;
  final WeekMoveController? move;
  final ValueChanged<WeekMoveResult>? onMoveResult;
  final NotificationListenerCallback<ScrollNotification>? onScrollNotification;
  final ScrollController? controller;
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

  static const ghostOpacity = WeekUiTokens.ghostOpacity;

  @override
  State<WeekCarouselUnified> createState() => WeekCarouselUnifiedState();
}

class WeekCarouselUnifiedState extends State<WeekCarouselUnified> {
  final _timedScroll = ScrollController();
  final _stripScroll = ScrollController();
  var _horizontalSyncing = false;
  ScrollController? _linkedPrimaryHorizontal;
  var _resizeExpanded = false;
  var _resizeActive = false;

  /// Viewport pin while hideEmptyWeekHours axis geometry changes from a gesture.
  WeekAxisViewportPin? _viewportPin;
  var _pinClearAfterApply = false;
  int? _liveMinutes;
  late final WeekPinchHourController _pinch;
  WeekHourAxis _axis = const WeekHourAxis(segments: []);
  double _stripHeight = 0;
  double _allDayHeight = 0;
  int _allDayReserveHours = 0;
  final _viewportBoxKey = GlobalKey();
  WeekCarouselDragAutoScroller? _resizeScroller;
  WeekCarouselDragAutoScroller? _moveScroller;
  ValueChanged<Offset>? _resizeApply;

  double get headerHeight => _stripHeight;
  WeekHourAxis get axis => _axis;
  double get verticalOffset =>
      _timedScroll.hasClients ? _timedScroll.offset : 0.0;
  double get allDayDockHeight => _allDayHeight;
  int get allDayReserveHours => _allDayReserveHours;

  WeekDropTarget? dropTargetAt(Offset globalPosition) {
    final box =
        _viewportBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || widget.columnWidth <= 0) return null;
    return weekCarouselDropTargetAt(
      globalPosition: globalPosition,
      viewportBox: box,
      scrollOffset: widget.controller != null && widget.controller!.hasClients
          ? widget.controller!.offset
          : 0.0,
      columnWidth: widget.columnWidth,
      laneDates: widget.laneDates,
      selectedDate: widget.selectedDate,
      headerHeight: 0,
      topDockHeight: _allDayHeight,
      timedScrollOffset: verticalOffset,
      axis: _axis,
      allDayReserveHours: _allDayReserveHours,
    );
  }

  double get _hourHeight => _pinch.hourHeight;

  @override
  void initState() {
    super.initState();
    _pinch = WeekPinchHourController(
      zoomLevel: widget.weekHourZoomLevel,
      stripHeight: CalendarDayBadgeLayout.weekStripHeightFromViewport(
        widget.viewportWidth,
      ),
    );
    _stripScroll.addListener(_syncPrimaryFromStrip);
    _linkPrimaryHorizontal(widget.controller);
    _moveScroller = WeekCarouselDragAutoScroller(
      viewportKey: _viewportBoxKey,
      scrollController: widget.controller,
      onVerticalScrollBy: scrollTimedBy,
      timedTopInset: () => 0,
    );
  }

  @override
  void didUpdateWidget(covariant WeekCarouselUnified oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _linkPrimaryHorizontal(widget.controller);
    }
    final strip = CalendarDayBadgeLayout.weekStripHeightFromViewport(
      widget.viewportWidth,
    );
    if (_pinch.syncFromProps(
      zoomLevel: widget.weekHourZoomLevel,
      stripHeight: strip,
    )) {
      // Height follows strip × level; rebuild via setState not needed if build
      // already reads _pinch.hourHeight — but keep pin when size changes.
    }
    // Parent forceFullHourAxis (event/slot drag): pin once on edges only.
    if (!oldWidget.forceFullHourAxis && widget.forceFullHourAxis) {
      if (_viewportPin == null) {
        _capturePin(null);
      }
      _pinClearAfterApply = true;
    } else if (oldWidget.forceFullHourAxis && !widget.forceFullHourAxis) {
      // Collapse after drag: capture current scroll, apply once, clear.
      if (!_resizeActive && widget.selectedSlot == null) {
        _capturePin(_viewportPin?.pinMinutes);
        _resizeExpanded = false;
        _pinClearAfterApply = true;
      }
    }

    final hadSlot = oldWidget.selectedSlot != null;
    final hasSlot = widget.selectedSlot != null;
    if (!hadSlot && hasSlot) {
      final slot = widget.selectedSlot!;
      if (_viewportPin == null) {
        _capturePin(slot.startMinutes);
      }
      _pinClearAfterApply = true;
    } else if (hadSlot && !hasSlot) {
      if (!_resizeActive && !widget.forceFullHourAxis) {
        _capturePin(_viewportPin?.pinMinutes);
        _resizeExpanded = false;
        _pinClearAfterApply = true;
      }
    } else if (hasSlot &&
        oldWidget.selectedSlot!.startMinutes !=
            widget.selectedSlot!.startMinutes) {
      retargetViewportPin(widget.selectedSlot!.startMinutes);
    }
  }

  void _linkPrimaryHorizontal(ScrollController? primary) {
    if (identical(_linkedPrimaryHorizontal, primary)) return;
    _linkedPrimaryHorizontal?.removeListener(_syncStripFromPrimary);
    _linkedPrimaryHorizontal = primary;
    primary?.addListener(_syncStripFromPrimary);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncStripFromPrimary();
    });
  }

  void _syncStripFromPrimary() {
    if (_horizontalSyncing) return;
    final primary = _linkedPrimaryHorizontal;
    if (primary == null || !primary.hasClients || !_stripScroll.hasClients) {
      return;
    }
    _horizontalSyncing = true;
    final target = primary.offset.clamp(
      0.0,
      _stripScroll.position.maxScrollExtent,
    );
    if ((target - _stripScroll.offset).abs() > 0.5) {
      _stripScroll.jumpTo(target);
    }
    _horizontalSyncing = false;
  }

  void _syncPrimaryFromStrip() {
    if (_horizontalSyncing) return;
    final primary = _linkedPrimaryHorizontal;
    if (primary == null || !primary.hasClients || !_stripScroll.hasClients) {
      return;
    }
    _horizontalSyncing = true;
    final target = _stripScroll.offset.clamp(
      0.0,
      primary.position.maxScrollExtent,
    );
    if ((target - primary.offset).abs() > 0.5) {
      primary.jumpTo(target);
    }
    _horizontalSyncing = false;
  }

  void scrollTimedBy(double delta) {
    if (delta.abs() < 0.01 || !_timedScroll.hasClients) return;
    final pos = _timedScroll.position;
    final target = (pos.pixels + delta).clamp(0.0, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() > 0.01) {
      _timedScroll.jumpTo(target);
    }
  }

  void _ensureResizeScroller() {
    _resizeScroller ??= WeekCarouselDragAutoScroller(
      viewportKey: _viewportBoxKey,
      horizontalEnabled: false,
      onVerticalScrollBy: _onResizeVerticalScroll,
      timedTopInset: () => 0,
    );
  }

  void _onResizeVerticalScroll(double delta) {
    scrollTimedBy(delta);
    final global = _resizeScroller?.lastGlobalPosition;
    if (global != null) {
      _resizeApply?.call(global);
    }
  }

  void _onResizeDragUpdate(Offset global) {
    _ensureResizeScroller();
    _resizeScroller!.updateDragPosition(global, horizontalEnabled: false);
  }

  void _onResizeApplyChanged(ValueChanged<Offset>? apply) {
    _resizeApply = apply;
    if (apply == null) {
      _resizeScroller?.stop();
    }
  }

  /// Avoid setState while this State (or an ancestor) is still building —
  /// child [didUpdateWidget] / scroll attach can fire during itemBuilder.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  int? minutesOfDayAt(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final local = box.globalToLocal(globalPosition);
    if (local.dy < headerHeight) return null;
    final timedViewportHeight = box.size.height - headerHeight;
    return weekTimedMinutesForContentY(
      axis: _axis,
      contentY: local.dy - headerHeight + verticalOffset,
      viewportHeight: timedViewportHeight,
      snap: true,
      topDockHeight: _allDayHeight,
    );
  }

  @override
  void dispose() {
    _resizeScroller?.dispose();
    _moveScroller?.dispose();
    _linkedPrimaryHorizontal?.removeListener(_syncStripFromPrimary);
    _stripScroll.removeListener(_syncPrimaryFromStrip);
    _stripScroll.dispose();
    _timedScroll.dispose();
    super.dispose();
  }

  bool get _axisExpanded =>
      widget.forceFullHourAxis ||
      _resizeExpanded ||
      widget.selectedSlot != null;

  double _timedViewportHeight() {
    return (widget.height - headerHeight).clamp(0.0, double.infinity);
  }

  double _bottomAlignPadFor(WeekHourAxis axis) {
    final contentHeight = _allDayHeight + axis.totalHeight;
    return weekTimedBottomAlignPad(
      axisHeight: contentHeight,
      viewportHeight: _timedViewportHeight(),
    );
  }

  void _capturePin(int? pinMinutes) {
    if (!widget.hideEmptyWeekHours) return;
    _viewportPin = WeekAxisViewportPin.capture(
      axis: _axis,
      scrollOffset: verticalOffset,
      pinMinutes: pinMinutes,
      bottomAlignPad: _bottomAlignPadFor(_axis),
      topDockHeight: _allDayHeight,
    );
  }

  /// Retarget pin minutes after a successful drop (keep viewportY).
  void retargetViewportPin(int minutes) {
    final pin = _viewportPin;
    if (pin == null) return;
    _viewportPin = pin.retargetMinutes(minutes);
  }

  /// Expand axis for event/slot move (timed scroll locks via [forceFullHourAxis]).
  void _beginAxisExpand(int pinMinutes) {
    if (!widget.hideEmptyWeekHours) return;
    if (_resizeExpanded && widget.forceFullHourAxis) {
      // Already expanded via parent forceFull; refresh pin once if needed.
      if (_viewportPin == null) _capturePin(pinMinutes);
      return;
    }
    if (!_resizeExpanded) {
      _capturePin(pinMinutes);
      _pinClearAfterApply = true; // clear after one expand apply
      _safeSetState(() => _resizeExpanded = true);
    } else if (_viewportPin == null) {
      _capturePin(pinMinutes);
    }
  }

  void _setResizeExpanded(bool expanded, {int? pinMinutes}) {
    if (!widget.hideEmptyWeekHours) {
      if (_resizeExpanded != expanded) {
        _safeSetState(() => _resizeExpanded = expanded);
      }
      return;
    }
    // Keep full axis while a create-slot is selected.
    if (!expanded && widget.selectedSlot != null) {
      if (_resizeExpanded) {
        _safeSetState(() => _resizeExpanded = false);
      }
      return;
    }
    if (_resizeExpanded == expanded) {
      if (expanded && pinMinutes != null) _capturePin(pinMinutes);
      return;
    }
    if (expanded) {
      _capturePin(pinMinutes);
      _pinClearAfterApply = true;
    } else {
      // Collapse: capture from current (expanded) scroll, then apply once.
      _capturePin(pinMinutes);
      _pinClearAfterApply = true;
    }
    _safeSetState(() => _resizeExpanded = expanded);
  }

  void _setLiveMinutes(int? minutes) {
    if (_liveMinutes == minutes) return;
    _safeSetState(() => _liveMinutes = minutes);
  }

  /// Apply pin only when [_pinClearAfterApply] is set (expand/collapse edge).
  /// Does not re-jump every build during a steady drag.
  void _applyPinnedScrollIfNeeded(WeekHourAxis axis) {
    final pin = _viewportPin;
    if (pin == null || !_pinClearAfterApply) return;
    _pinClearAfterApply = false;
    final shouldClear =
        !_resizeActive &&
        !widget.forceFullHourAxis &&
        widget.selectedSlot == null;
    if (shouldClear) {
      _viewportPin = null;
    }
    final pad = _bottomAlignPadFor(axis);
    final dock = _allDayHeight;
    final pinToApply = pin;
    weekAxisApplyPinPostFrame(
      pin: pinToApply,
      axis: axis,
      bottomAlignPad: pad,
      topDockHeight: dock,
      isMounted: () => mounted,
      maxScrollExtent: () {
        if (!_timedScroll.hasClients) return 0.0;
        return _timedScroll.position.maxScrollExtent;
      },
      jumpTo: (offset) {
        if (!_timedScroll.hasClients) return;
        _timedScroll.jumpTo(offset);
      },
    );
  }

  void _onPinchPointerDown(PointerDownEvent event) {
    if (_resizeActive || widget.forceFullHourAxis) return;
    final focal = _pinch.handlePointerDown(event);
    if (focal == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(focal);
    if (local.dy < headerHeight) return;
    final timedViewportHeight = box.size.height - headerHeight;
    final contentY = local.dy - headerHeight + verticalOffset;
    _capturePin(
      weekTimedMinutesForContentY(
        axis: _axis,
        contentY: contentY,
        viewportHeight: timedViewportHeight,
        topDockHeight: _allDayHeight,
      ),
    );
    _pinClearAfterApply = true;
  }

  void _onPinchPointerMove(PointerMoveEvent event) {
    if (_resizeActive || widget.forceFullHourAxis) return;
    if (_pinch.handlePointerMove(event)) {
      _safeSetState(() {});
    }
  }

  void _onPinchPointerUp(PointerEvent event) {
    if (_resizeActive || widget.forceFullHourAxis) {
      _pinch.handlePointerUp(event);
      return;
    }
    final result = _pinch.handlePointerUp(event);
    if (result.snappedLevel != null) {
      widget.onWeekHourZoomLevelChanged?.call(result.snappedLevel!);
    }
    if (result.heightChanged || result.snappedLevel != null) {
      _pinClearAfterApply = true;
      _safeSetState(() {});
    }
  }

  void _beginResizeExpand(int pin) {
    _resizeActive = true;
    _setResizeExpanded(true, pinMinutes: pin);
  }

  void _endResizeExpand() {
    _resizeActive = false;
    _setResizeExpanded(false);
    _resizeScroller?.stop();
  }

  @override
  Widget build(BuildContext context) {
    final lanes = weekCarouselLanes(
      dates: widget.laneDates,
      selectedDate: widget.selectedDate,
    );
    const visibleDays = DateCellLayout.weekCarouselVisibleDays;
    final maxSnapPage = weekCarouselMaxSnapPage(
      laneCount: lanes.length,
      visibleColumns: visibleDays,
    );
    final stripHeight = CalendarDayBadgeLayout.weekStripHeightFromViewport(
      widget.viewportWidth,
    );
    _pinch.syncFromProps(
      zoomLevel: widget.weekHourZoomLevel,
      stripHeight: stripHeight,
    );
    final dragEnabled = widget.onEventMoved != null;
    final slotMoveEnabled = widget.onSelectedSlotChanged != null;
    final moveLayerEnabled =
        widget.move != null && (dragEnabled || slotMoveEnabled);
    final eventsByDay = {
      for (final lane in lanes)
        lane.date: dayEventsForWeekColumn(
          eventsIndex: widget.eventsIndex,
          date: lane.date,
          activeProfileId: widget.activeProfileId,
        ),
    };
    final timedEvents = [
      for (final events in eventsByDay.values)
        for (final event in events)
          if (event.isTimed) event,
    ];
    final allDayCount = maxAllDayCount(eventsByDay.values);
    _allDayReserveHours = weekAllDayReserveHours(
      allDayCount,
      hourHeight: _hourHeight,
    );
    _axis = WeekHourAxis.fromEvents(
      events: timedEvents,
      hideEmptyHours: widget.hideEmptyWeekHours,
      expanded: _axisExpanded,
      hourHeight: _hourHeight,
      paddingBefore: widget.weekHourPaddingBefore,
      paddingAfter: widget.weekHourPaddingAfter,
      allDayReserveHours: _allDayReserveHours,
      extraRangeStartMinutes: widget.selectedSlot?.startMinutes,
      extraRangeEndMinutes: widget.selectedSlot?.endMinutes,
    );
    _applyPinnedScrollIfNeeded(_axis);
    // ignore: deprecated_member_use_from_same_package
    final allDayHeight = weekAllDayBandHeightForCounts(
      allDayCount,
      hourHeight: _hourHeight,
    );
    _stripHeight = stripHeight;
    _allDayHeight = allDayHeight;

    final horizontalPhysics = widget.scrollLocked
        ? const NeverScrollableScrollPhysics()
        : weekCarouselSnapScrollPhysics(
            widget.columnWidth,
            maxSnapPage: maxSnapPage,
          );

    Widget stripCarousel = SizedBox(
      height: stripHeight,
      child: ListView.builder(
        controller: _stripScroll,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        cacheExtent: weekCarouselCacheExtent(widget.columnWidth),
        itemExtent: widget.columnWidth,
        itemCount: lanes.length,
        physics: horizontalPhysics,
        itemBuilder: (context, laneIndex) {
          final lane = lanes[laneIndex];
          return KeyedSubtree(
            key: ValueKey('strip-${lane.date}'),
            child: _WeekCarouselStripCell(
              date: lane.date,
              ghost: lane.ghost,
              selectedDate: widget.selectedDate,
              onDateSelected: widget.onDateSelected,
              onDateLongPress: widget.onDateLongPress,
            ),
          );
        },
      ),
    );

    Widget timedViewport = Listener(
            onPointerDown: _onPinchPointerDown,
            onPointerMove: _onPinchPointerMove,
            onPointerUp: _onPinchPointerUp,
            onPointerCancel: _onPinchPointerUp,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport = constraints.maxHeight;
                final bodyHeight = allDayHeight + _axis.totalHeight;
                final labelWidth = weekHourLabelSlotWidth(_axis.hourHeight);
                return Stack(
                  children: [
                    ScrollConfiguration(
                      behavior: const AlmanacNoScrollbarBehavior(),
                      child: SingleChildScrollView(
                        controller: _timedScroll,
                        physics: (_resizeActive || widget.forceFullHourAxis)
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: viewport),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              height: bodyHeight,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: allDayHeight,
                                    left: 0,
                                    right: 0,
                                    height: _axis.totalHeight,
                                    child: IgnorePointer(
                                      child: WeekHourGridLines(
                                        axis: _axis,
                                        monolithic: true,
                                      ),
                                    ),
                                  ),
                                  ListView.builder(
                                    controller: widget.controller,
                                    scrollDirection: Axis.horizontal,
                                    padding: EdgeInsets.zero,
                                    cacheExtent: weekCarouselCacheExtent(
                                      widget.columnWidth,
                                    ),
                                    itemExtent: widget.columnWidth,
                                    itemCount: lanes.length,
                                    physics: horizontalPhysics,
                                    itemBuilder: (context, laneIndex) {
                                      final lane = lanes[laneIndex];
                                      return KeyedSubtree(
                                        key: ValueKey(lane.date),
                                        child: _WeekCarouselLaneColumn(
                                          date: lane.date,
                                          ghost: lane.ghost,
                                          axis: _axis,
                                          selectedDate: widget.selectedDate,
                                          events:
                                              eventsByDay[lane.date] ??
                                              const [],
                                          activeProfileId:
                                              widget.activeProfileId,
                                          colorFilter: widget.colorFilter,
                                          profileSeedColors:
                                              widget.profileSeedColors,
                                          profileNamesById:
                                              widget.profileNamesById,
                                          onDateSelected: widget.onDateSelected,
                                          onDateLongPress:
                                              widget.onDateLongPress,
                                          onEditEvent: widget.onEditEvent,
                                          onEventUpdated: widget.onEventUpdated,
                                          onShiftQuickAction:
                                              widget.onShiftQuickAction,
                                          moveEnabled:
                                              dragEnabled && !lane.ghost,
                                          onResizeStarted: _beginResizeExpand,
                                          onHourAxisExpand: _beginAxisExpand,
                                          onEventResized: widget.onEventResized,
                                          onResizeEnded: _endResizeExpand,
                                          onResizeDragUpdate:
                                              _onResizeDragUpdate,
                                          onResizeApplyChanged:
                                              _onResizeApplyChanged,
                                          showDivider:
                                              laneIndex < lanes.length - 1,
                                          hideEmptyWeekHours:
                                              widget.hideEmptyWeekHours,
                                          forceFullHourAxis: _axisExpanded,
                                          dragSession: widget.dragSession,
                                          onEmptySlotTap: widget.onEmptySlotTap,
                                          selectedSlot: widget.selectedSlot,
                                          onSelectedSlotChanged:
                                              widget.onSelectedSlotChanged,
                                          onLiveMinutesChanged: _setLiveMinutes,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: labelWidth,
                      child: IgnorePointer(
                        child: WeekTimedScrollLayer(
                          scrollController: _timedScroll,
                          viewportHeight: viewport,
                          bodyHeight: bodyHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: allDayHeight,
                                left: 0,
                                width: labelWidth,
                                height: _axis.totalHeight,
                                child: WeekHourLabels(
                                  axis: _axis,
                                  liveMinutes: _liveMinutes,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _CarouselNowLineOverlay(
                          timedScroll: _timedScroll,
                          horizontalScroll: widget.controller,
                          viewportHeight: viewport,
                          bodyHeight: bodyHeight,
                          allDayHeight: allDayHeight,
                          axis: _axis,
                          lanes: lanes,
                          columnWidth: widget.columnWidth,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        );

    final move = widget.move;
    if (move != null) {
      timedViewport = WeekTimedDragLayer(
        move: move,
        enabled: moveLayerEnabled,
        axis: _axis,
        dates: [for (final lane in lanes) lane.date],
        columnWidth: widget.columnWidth,
        timedScroll: _timedScroll,
        horizontalScroll: widget.controller,
        allDayHeight: allDayHeight,
        onActiveChanged: (active, pinMinutes) {
          if (active && widget.hideEmptyWeekHours && pinMinutes != null) {
            _beginAxisExpand(pinMinutes);
          } else if (!active) {
            _setResizeExpanded(false);
          }
        },
        onDragPointer: (global) {
          _moveScroller?.updateDragPosition(global);
        },
        onResult: (result) {
          _moveScroller?.stop();
          _setResizeExpanded(false);
          widget.onMoveResult?.call(result);
        },
        child: timedViewport,
      );
    }

    Widget timedCarousel = Expanded(
      child: KeyedSubtree(
        key: _viewportBoxKey,
        child: timedViewport,
      ),
    );

    Widget carousel = SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [stripCarousel, timedCarousel],
      ),
    );

    if (widget.onScrollNotification != null) {
      carousel = NotificationListener<ScrollNotification>(
        onNotification: widget.onScrollNotification,
        child: carousel,
      );
    }

    return carousel;
  }
}

class _CarouselNowLineOverlay extends StatelessWidget {
  const _CarouselNowLineOverlay({
    required this.timedScroll,
    required this.horizontalScroll,
    required this.viewportHeight,
    required this.bodyHeight,
    required this.allDayHeight,
    required this.axis,
    required this.lanes,
    required this.columnWidth,
  });

  final ScrollController timedScroll;
  final ScrollController? horizontalScroll;
  final double viewportHeight;
  final double bodyHeight;
  final double allDayHeight;
  final WeekHourAxis axis;
  final List<({DateTime date, bool ghost})> lanes;
  final double columnWidth;

  @override
  Widget build(BuildContext context) {
    final todayIndex = lanes.indexWhere(
      (lane) => isSameCalendarDay(lane.date, DateTime.now()),
    );
    if (todayIndex < 0) return const SizedBox.shrink();

    final listenable = horizontalScroll == null
        ? Listenable.merge([timedScroll])
        : Listenable.merge([timedScroll, horizontalScroll!]);

    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        final hOffset = horizontalScroll != null && horizontalScroll!.hasClients
            ? horizontalScroll!.offset
            : 0.0;
        final left = todayIndex * columnWidth - hOffset;
        return WeekTimedScrollLayer(
          scrollController: timedScroll,
          viewportHeight: viewportHeight,
          bodyHeight: bodyHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                width: columnWidth,
                top: allDayHeight,
                height: axis.totalHeight,
                child: WeekNowLine(axis: axis, date: lanes[todayIndex].date),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekCarouselStripCell extends StatelessWidget {
  const _WeekCarouselStripCell({
    required this.date,
    required this.ghost,
    required this.selectedDate,
    required this.onDateSelected,
    this.onDateLongPress,
  });

  final DateTime date;
  final bool ghost;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;

  @override
  Widget build(BuildContext context) {
    Widget cell = CalendarDayBadge(
      key: ValueKey('carousel-strip-${date.toIso8601String()}'),
      date: date,
      selected: !ghost && isSameCalendarDay(date, selectedDate),
      onTap: () => onDateSelected(date),
      onLongPress: onDateLongPress == null
          ? null
          : () => onDateLongPress!(date),
      expandToWidth: true,
      interactive: true,
    );
    if (ghost) {
      cell = Opacity(opacity: WeekCarouselUnified.ghostOpacity, child: cell);
    }
    return cell;
  }
}

class _WeekCarouselLaneColumn extends StatelessWidget {
  const _WeekCarouselLaneColumn({
    required this.date,
    required this.ghost,
    required this.axis,
    required this.selectedDate,
    required this.events,
    required this.activeProfileId,
    required this.colorFilter,
    required this.profileSeedColors,
    required this.profileNamesById,
    required this.onDateSelected,
    required this.onDateLongPress,
    required this.onEditEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    required this.moveEnabled,
    this.onResizeStarted,
    this.onHourAxisExpand,
    this.onEventResized,
    this.onResizeEnded,
    this.onResizeDragUpdate,
    this.onResizeApplyChanged,
    required this.showDivider,
    required this.hideEmptyWeekHours,
    required this.forceFullHourAxis,
    required this.dragSession,
    this.onEmptySlotTap,
    this.selectedSlot,
    this.onSelectedSlotChanged,
    this.onLiveMinutesChanged,
  });

  final DateTime date;
  final bool ghost;
  final WeekHourAxis axis;
  final DateTime selectedDate;
  final List<AppEvent> events;
  final String activeProfileId;
  final Set<int> colorFilter;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final bool moveEnabled;
  final ValueChanged<int>? onResizeStarted;
  final ValueChanged<int>? onHourAxisExpand;
  final WeekEventResizeCallback? onEventResized;
  final VoidCallback? onResizeEnded;
  final ValueChanged<Offset>? onResizeDragUpdate;
  final ValueChanged<ValueChanged<Offset>?>? onResizeApplyChanged;
  final bool showDivider;
  final bool hideEmptyWeekHours;
  final bool forceFullHourAxis;
  final WeekDragSession dragSession;
  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;
  final ValueChanged<int?>? onLiveMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final eventsColumn = WeekDayColumn(
      date: date,
      events: events,
      selected: !ghost && isSameCalendarDay(date, selectedDate),
      activeProfileId: activeProfileId,
      colorFilter: colorFilter,
      profileSeedColors: profileSeedColors,
      profileNamesById: profileNamesById,
      onEditEvent: ghost ? (_) {} : onEditEvent,
      onEventUpdated: ghost ? null : onEventUpdated,
      onShiftQuickAction: ghost ? null : onShiftQuickAction,
      moveEnabled: moveEnabled,
      onResizeStarted: ghost ? null : onResizeStarted,
      onHourAxisExpand: ghost ? null : onHourAxisExpand,
      onEventResized: ghost ? null : onEventResized,
      onResizeEnded: ghost ? null : onResizeEnded,
      onResizeDragUpdate: ghost ? null : onResizeDragUpdate,
      onResizeApplyChanged: ghost ? null : onResizeApplyChanged,
      showDivider: showDivider,
      axis: axis,
      scrollTimedGrid: false,
      showHourLabels: false,
      paintHourLines: false,
      showNowLine: false,
      hideEmptyWeekHours: hideEmptyWeekHours,
      forceFullHourAxis: forceFullHourAxis,
      dragSession: dragSession,
      onEmptySlotTap: ghost ? null : onEmptySlotTap,
      selectedSlot: ghost ? null : selectedSlot,
      onSelectedSlotChanged: ghost ? null : onSelectedSlotChanged,
      onLiveMinutesChanged: ghost ? null : onLiveMinutesChanged,
    );

    Widget column = eventsColumn;
    if (ghost) {
      column = RepaintBoundary(
        child: Opacity(
          opacity: WeekCarouselUnified.ghostOpacity,
          child: column,
        ),
      );
    } else {
      column = RepaintBoundary(child: column);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => onDateSelected(date),
      onLongPress: onDateLongPress == null
          ? null
          : () => onDateLongPress!(date),
      child: column,
    );
  }
}
