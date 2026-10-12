import 'package:flutter/material.dart';
import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../chrome/event_day_markers.dart';
import '../schedule_quick_actions_bar.dart';
import 'week_axis_viewport_pin.dart';
import 'week_carousel_drag_autoscroll.dart';
import 'week_day_column.dart';
import 'week_day_timeline.dart';
import 'week_drag_policy.dart';
import 'week_drop_hit_test.dart';
import 'week_move_controller.dart';
import 'week_move_types.dart';
import 'week_hour_axis.dart';
import 'week_hour_grid.dart';
import 'week_hour_layout.dart';
import 'week_grid_slot.dart';
import 'week_pinch_hour_controller.dart';
import 'week_timed_drag_layer.dart';
import 'week_ui_tokens.dart';
import '../chrome/calendar_day_badge.dart';

/// Сетка колонок недели. Preview/commit — через [WeekMoveController] родителя.
class WeekEventsDropGrid extends StatefulWidget {
  const WeekEventsDropGrid({
    super.key,
    required this.weekDates,
    required this.eventsIndex,
    required this.selectedDate,
    required this.activeProfileId,
    required this.onEditEvent,
    this.onEventUpdated,
    this.onShiftQuickAction,
    this.colorFilter = const {},
    this.profileSeedColors = const {},
    this.profileNamesById = const {},
    this.onEventMoved,
    this.onEventResized,
    this.onDragActiveChanged,
    this.columnWidth,
    this.controller,
    this.viewportKey,
    this.hideEmptyWeekHours = false,
    this.weekHourPaddingBefore = 2,
    this.weekHourPaddingAfter = 1,
    this.weekHourZoomLevel = kWeekHourZoomLevelDefault,
    this.onWeekHourZoomLevelChanged,
    this.dragSession = WeekDragSession.empty,
    this.onEmptySlotTap,
    this.selectedSlot,
    this.onSelectedSlotChanged,
    this.move,
    this.onMoveResult,
    this.forceFullHourAxis = false,
  });

  final List<DateTime> weekDates;
  final Map<DateTime, List<AppEvent>> eventsIndex;
  final DateTime selectedDate;
  final String activeProfileId;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final Set<int> colorFilter;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final WeekEventMoveCallback? onEventMoved;
  final WeekEventResizeCallback? onEventResized;
  final ValueChanged<bool>? onDragActiveChanged;

  /// Фиксированная ширина колонки в режиме карусели (иначе — равные доли).
  final double? columnWidth;

  /// Контроллер горизонтальной прокрутки карусели (синхрон с полоской дат).
  final ScrollController? controller;

  /// Видимая область карусели — для автопрокрутки при перетаскивании.
  final GlobalKey? viewportKey;

  final bool hideEmptyWeekHours;
  final int weekHourPaddingBefore;
  final int weekHourPaddingAfter;
  final int weekHourZoomLevel;
  final ValueChanged<int>? onWeekHourZoomLevelChanged;
  final WeekDragSession dragSession;
  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;
  final WeekMoveController? move;
  final ValueChanged<WeekMoveResult>? onMoveResult;
  final bool forceFullHourAxis;

  @override
  State<WeekEventsDropGrid> createState() => WeekEventsDropGridState();
}

class WeekEventsDropGridState extends State<WeekEventsDropGrid> {
  var _axisExpanded = false;
  var _resizeActive = false;
  WeekAxisViewportPin? _viewportPin;
  var _pinClearAfterApply = false;
  int? _liveMinutes;
  late final WeekPinchHourController _pinch;
  final _timedScroll = ScrollController();
  final _timedViewportKey = GlobalKey();
  WeekHourAxis _axis = const WeekHourAxis(segments: []);
  WeekCarouselDragAutoScroller? _edgeScroller;
  ValueChanged<Offset>? _resizeApply;
  double _allDayDockHeight = 0;
  int _allDayReserveHours = 0;

  double get _hourHeight => _pinch.hourHeight;

  double _timedColumnWidth(RenderBox box) {
    if (widget.columnWidth != null && widget.columnWidth! > 0) {
      return widget.columnWidth!;
    }
    return box.size.width / widget.weekDates.length.clamp(1, 31);
  }

  /// Expanded for drag/resize OR while a create-slot is selected.
  bool get _axisFullyExpanded =>
      _axisExpanded || widget.forceFullHourAxis || widget.selectedSlot != null;

  @override
  void initState() {
    super.initState();
    _pinch = WeekPinchHourController(zoomLevel: widget.weekHourZoomLevel);
  }

  WeekDropTarget? dropTargetAt(Offset globalPosition) =>
      _gridDropTargetAt(globalPosition);

  void retargetViewportPin(int minutes) {
    final pin = _viewportPin;
    if (pin == null) return;
    _viewportPin = pin.retargetMinutes(minutes);
  }

  @override
  void didUpdateWidget(covariant WeekEventsDropGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadSlot = oldWidget.selectedSlot != null;
    final hasSlot = widget.selectedSlot != null;
    if (!hadSlot && hasSlot) {
      final slot = widget.selectedSlot!;
      if (_viewportPin == null) {
        _capturePin(slot.startMinutes);
      }
      _pinClearAfterApply = true;
    } else if (hadSlot && !hasSlot) {
      if (!_resizeActive && !_axisExpanded) {
        _capturePin(_viewportPin?.pinMinutes);
        _pinClearAfterApply = true;
      }
    } else if (hasSlot &&
        oldWidget.selectedSlot!.startMinutes !=
            widget.selectedSlot!.startMinutes) {
      final pin = _viewportPin;
      if (pin != null) {
        _viewportPin = pin.retargetMinutes(widget.selectedSlot!.startMinutes);
      }
    }
  }

  @override
  void dispose() {
    _edgeScroller?.dispose();
    _timedScroll.dispose();
    super.dispose();
  }

  Map<DateTime, List<AppEvent>> _eventsByDay() {
    return {
      for (final date in widget.weekDates)
        date: dayEventsForWeekColumn(
          eventsIndex: widget.eventsIndex,
          date: date,
          activeProfileId: widget.activeProfileId,
        ),
    };
  }

  void _capturePin(int? pinMinutes) {
    if (!widget.hideEmptyWeekHours) return;
    final scroll = _timedScroll.hasClients ? _timedScroll.offset : 0.0;
    final viewportHeight = _timedViewportHeight();
    final contentHeight = _allDayDockHeight + _axis.totalHeight;
    final pad = weekTimedBottomAlignPad(
      axisHeight: contentHeight,
      viewportHeight: viewportHeight,
    );
    _viewportPin = WeekAxisViewportPin.capture(
      axis: _axis,
      scrollOffset: scroll,
      pinMinutes: pinMinutes,
      bottomAlignPad: pad,
      topDockHeight: _allDayDockHeight,
    );
  }

  double _timedViewportHeight() {
    final box =
        _timedViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return 0;
    return box.size.height;
  }

  /// Expand for move-drag; timed scroll locks while [_axisExpanded].
  void _beginAxisExpand(int pinMinutes) {
    if (!widget.hideEmptyWeekHours) return;
    if (_axisExpanded) {
      if (_viewportPin == null) _capturePin(pinMinutes);
      return;
    }
    _capturePin(pinMinutes);
    _pinClearAfterApply = true;
    setState(() => _axisExpanded = true);
    widget.onDragActiveChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_axisExpanded) return;
      widget.move?.refreshAfterLayout();
    });
  }

  void _setExpanded(bool expanded, {int? pinMinutes}) {
    if (!widget.hideEmptyWeekHours) {
      if (_axisExpanded != expanded) {
        setState(() => _axisExpanded = expanded);
        widget.onDragActiveChanged?.call(expanded);
      }
      return;
    }
    // Drag/resize flag only; selectedSlot keeps full axis via [_axisFullyExpanded].
    if (_axisExpanded == expanded) {
      if (expanded && pinMinutes != null) {
        _capturePin(pinMinutes);
      }
      return;
    }
    _capturePin(pinMinutes ?? widget.selectedSlot?.startMinutes);
    _pinClearAfterApply = true;
    setState(() => _axisExpanded = expanded);
    widget.onDragActiveChanged?.call(expanded);
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    if (weekAxisSchedulerIsBuilding()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  void _setLiveMinutes(int? minutes) {
    if (_liveMinutes == minutes) return;
    _safeSetState(() => _liveMinutes = minutes);
  }

  int get _allDayReserve => _allDayReserveHours;

  WeekDropTarget? _gridDropTargetAt(Offset globalPosition) {
    final box =
        _timedViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return weekDropTargetAt(
      globalPosition: globalPosition,
      viewportBox: box,
      columnWidth: _timedColumnWidth(box),
      dayDates: widget.weekDates,
      timedScrollOffset: _timedScroll.hasClients ? _timedScroll.offset : 0,
      // Timed viewport includes all-day dock at top of scroll content.
      headerHeight: 0,
      topDockHeight: _allDayDockHeight,
      axis: _axis,
      allDayReserveHours: _allDayReserve,
    );
  }

  void _scrollTimedByEdge(double delta) {
    if (!_timedScroll.hasClients) return;
    final pos = _timedScroll.position;
    final target = (pos.pixels + delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if ((target - pos.pixels).abs() < 0.01) return;
    _timedScroll.jumpTo(target);
    final global = _edgeScroller?.lastGlobalPosition;
    if (global != null) {
      _resizeApply?.call(global);
      if (widget.move?.active ?? false) {
        widget.move!.update(global);
      }
    }
  }

  void _applyPinnedScrollIfNeeded(WeekHourAxis axis) {
    final pin = _viewportPin;
    if (pin == null || !_pinClearAfterApply) return;
    _pinClearAfterApply = false;
    final shouldClear =
        !_resizeActive && !_axisExpanded && widget.selectedSlot == null;
    if (shouldClear) {
      _viewportPin = null;
    }
    final dock = _allDayDockHeight;
    weekAxisApplyPinPostFrame(
      pin: pin,
      axis: axis,
      topDockHeight: dock,
      isMounted: () => mounted,
      bottomAlignPad: weekTimedBottomAlignPad(
        axisHeight: dock + axis.totalHeight,
        viewportHeight: _timedViewportHeight(),
      ),
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
    if (_resizeActive || _axisFullyExpanded) return;
    final focal = _pinch.handlePointerDown(event);
    if (focal == null || !_timedScroll.hasClients) return;
    final box =
        _timedViewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(focal);
    final contentY = local.dy + _timedScroll.offset;
    _capturePin(
      weekTimedMinutesForContentY(
        axis: _axis,
        contentY: contentY,
        viewportHeight: box.size.height,
        topDockHeight: _allDayDockHeight,
      ),
    );
    _pinClearAfterApply = true;
  }

  void _onPinchPointerMove(PointerMoveEvent event) {
    if (_resizeActive || _axisFullyExpanded) return;
    if (_pinch.handlePointerMove(event)) {
      setState(() {});
    }
  }

  void _onPinchPointerUp(PointerEvent event) {
    if (_resizeActive || _axisFullyExpanded) {
      _pinch.handlePointerUp(event);
      return;
    }
    final result = _pinch.handlePointerUp(event);
    if (result.snappedLevel != null) {
      widget.onWeekHourZoomLevelChanged?.call(result.snappedLevel!);
    }
    if (result.heightChanged || result.snappedLevel != null) {
      setState(() {});
    }
    if (!_pinch.isPinching) {
      _pinClearAfterApply = true;
      _applyPinnedScrollIfNeeded(_axis);
    }
  }

  void _beginResizeExpand(int pin) {
    _resizeActive = true;
    _setExpanded(true, pinMinutes: pin);
  }

  void _endResizeExpand() {
    _resizeActive = false;
    _setExpanded(false);
    _edgeScroller?.stop();
  }

  void _ensureEdgeScroller() {
    _edgeScroller ??= WeekCarouselDragAutoScroller(
      viewportKey: _timedViewportKey,
      scrollController: _timedScroll,
      horizontalEnabled: false,
      onVerticalScrollBy: _scrollTimedByEdge,
      timedTopInset: () => 0,
    );
  }

  void _onResizeDragUpdate(Offset global) {
    _ensureEdgeScroller();
    _edgeScroller!.updateDragPosition(global, horizontalEnabled: false);
  }

  void _onResizeApplyChanged(ValueChanged<Offset>? apply) {
    _resizeApply = apply;
    if (apply == null) {
      _edgeScroller?.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, shellConstraints) {
        final dragEnabled = widget.onEventMoved != null;
        final slotMoveEnabled = widget.onSelectedSlotChanged != null;
        final moveLayerEnabled =
            widget.move != null && (dragEnabled || slotMoveEnabled);
        final stripHeight = CalendarDayBadgeLayout.weekStripHeightFromViewport(
          shellConstraints.maxWidth,
        );
        _pinch.syncFromProps(
          zoomLevel: widget.weekHourZoomLevel,
          stripHeight: stripHeight,
        );
        final eventsByDay = _eventsByDay();
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
          expanded: _axisFullyExpanded,
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
        _allDayDockHeight = allDayHeight;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: KeyedSubtree(
                      key: _timedViewportKey,
                      child: LayoutBuilder(
                        builder: (context, viewportConstraints) {
                          final box =
                              context.findRenderObject() as RenderBox?;
                          final columnWidth = box != null && box.hasSize
                              ? _timedColumnWidth(box)
                              : widget.columnWidth ??
                                  viewportConstraints.maxWidth /
                                      widget.weekDates.length.clamp(1, 31);
                          Widget timedBody = Listener(
                          onPointerDown: _onPinchPointerDown,
                          onPointerMove: _onPinchPointerMove,
                          onPointerUp: _onPinchPointerUp,
                          onPointerCancel: _onPinchPointerUp,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewport = constraints.maxHeight;
                              final bodyHeight =
                                  allDayHeight + _axis.totalHeight;
                              return SingleChildScrollView(
                                controller: _timedScroll,
                                physics: (_resizeActive || _axisExpanded)
                                    ? const NeverScrollableScrollPhysics()
                                    : null,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: viewport,
                                  ),
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
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              for (
                                                var i = 0;
                                                i < widget.weekDates.length;
                                                i++
                                              )
                                                Expanded(
                                                  child: WeekDayColumn(
                                                            date: widget
                                                                .weekDates[i],
                                                            events:
                                                                eventsByDay[widget
                                                                    .weekDates[i]] ??
                                                                const [],
                                                            selected: isSameCalendarDay(
                                                              widget
                                                                  .weekDates[i],
                                                              widget
                                                                  .selectedDate,
                                                            ),
                                                            activeProfileId: widget
                                                                .activeProfileId,
                                                            colorFilter: widget
                                                                .colorFilter,
                                                            profileSeedColors:
                                                                widget
                                                                    .profileSeedColors,
                                                            profileNamesById: widget
                                                                .profileNamesById,
                                                            onEditEvent: widget
                                                                .onEditEvent,
                                                            moveEnabled:
                                                                dragEnabled ||
                                                                slotMoveEnabled,
                                                            onResizeStarted:
                                                                _beginResizeExpand,
                                                            onHourAxisExpand:
                                                                dragEnabled ||
                                                                    slotMoveEnabled
                                                                ? _beginAxisExpand
                                                                : null,
                                                            onEventResized: widget
                                                                .onEventResized,
                                                            onResizeEnded:
                                                                _endResizeExpand,
                                                            onResizeDragUpdate:
                                                                _onResizeDragUpdate,
                                                            onResizeApplyChanged:
                                                                _onResizeApplyChanged,
                                                            showDivider:
                                                                i <
                                                                widget
                                                                        .weekDates
                                                                        .length -
                                                                    1,
                                                            showAllDayBand:
                                                                true,
                                                            showTimedGrid: true,
                                                            scrollTimedGrid:
                                                                false,
                                                            showHourLabels:
                                                                false,
                                                            paintHourLines:
                                                                false,
                                                            showNowLine: false,
                                                            axis: _axis,
                                                            hideEmptyWeekHours:
                                                                widget
                                                                    .hideEmptyWeekHours,
                                                            forceFullHourAxis:
                                                                _axisFullyExpanded,
                                                            dragSession:
                                                                widget.dragSession,
                                                            onEmptySlotTap: widget
                                                                .onEmptySlotTap,
                                                            selectedSlot: widget
                                                                .selectedSlot,
                                                            onSelectedSlotChanged:
                                                                widget
                                                                    .onSelectedSlotChanged,
                                                            onLiveMinutesChanged:
                                                                _setLiveMinutes,
                                                          ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                          final move = widget.move;
                          if (move != null) {
                            timedBody = WeekTimedDragLayer(
                              move: move,
                              enabled: moveLayerEnabled,
                              axis: _axis,
                              dates: widget.weekDates,
                              columnWidth: columnWidth,
                              timedScroll: _timedScroll,
                              allDayHeight: allDayHeight,
                              onActiveChanged: (active, pinMinutes) {
                                if (active &&
                                    widget.hideEmptyWeekHours &&
                                    pinMinutes != null) {
                                  _beginAxisExpand(pinMinutes);
                                } else if (!active) {
                                  _setExpanded(false);
                                }
                              },
                              onDragPointer: (global) {
                                _ensureEdgeScroller();
                                _edgeScroller!.updateDragPosition(
                                  global,
                                  horizontalEnabled: false,
                                );
                              },
                              onResult: (result) {
                                _edgeScroller?.stop();
                                _setExpanded(false);
                                widget.onMoveResult?.call(result);
                              },
                              child: timedBody,
                            );
                          }
                          return timedBody;
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: weekHourLabelSlotWidth(_axis.hourHeight),
                    child: IgnorePointer(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final viewport = constraints.maxHeight;
                          final bodyHeight = allDayHeight + _axis.totalHeight;
                          final labelWidth = weekHourLabelSlotWidth(
                            _axis.hourHeight,
                          );
                          return WeekTimedScrollLayer(
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
                          );
                        },
                      ),
                    ),
                  ),
                  if (widget.weekDates.any(
                    (date) => isSameCalendarDay(date, DateTime.now()),
                  ))
                    Positioned.fill(
                      child: IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final viewport = constraints.maxHeight;
                            final bodyHeight = allDayHeight + _axis.totalHeight;
                            final todayIndex = widget.weekDates.indexWhere(
                              (date) => isSameCalendarDay(date, DateTime.now()),
                            );
                            if (todayIndex < 0) {
                              return const SizedBox.shrink();
                            }
                            final colWidth =
                                constraints.maxWidth / widget.weekDates.length;
                            return WeekTimedScrollLayer(
                              scrollController: _timedScroll,
                              viewportHeight: viewport,
                              bodyHeight: bodyHeight,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: colWidth * todayIndex,
                                    width: colWidth,
                                    top: allDayHeight,
                                    height: _axis.totalHeight,
                                    child: WeekNowLine(
                                      axis: _axis,
                                      date: widget.weekDates[todayIndex],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}

List<AppEvent> dayEventsForWeekColumn({
  required Map<DateTime, List<AppEvent>> eventsIndex,
  required DateTime date,
  required String activeProfileId,
}) {
  return sortWeekColumnEvents(
    prioritizeEventsForProfile(
      List<AppEvent>.from(eventsForDay(eventsIndex, date)),
      activeProfileId,
    ),
  );
}
