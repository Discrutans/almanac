import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_scroll.dart';
import '../../calendar_types.dart';
import '../../event_time_utils.dart';
import '../schedule_quick_actions_bar.dart';
import 'week_day_timeline.dart';
import 'week_drag_policy.dart';
import 'week_hour_axis.dart';
import 'week_hour_event_tile.dart';
import 'week_hour_grid.dart';
import 'week_hour_layout.dart';
import 'week_grid_slot.dart';
import 'week_move_controller.dart';
import 'week_move_offer.dart';
import 'week_move_scope.dart';
import 'week_move_types.dart';
import 'week_selection_frame.dart';
import 'week_ui_tokens.dart';

typedef WeekEventMoveCallback =
    void Function(AppEvent event, DateTime targetDate, [TimeOfDay? startTime]);
typedef WeekEventResizeCallback =
    void Function(AppEvent event, int startMinutes, int endMinutes);

/// Колонка одного дня недели: часовая сетка; безвременные — в scrollable dock.
class WeekDayColumn extends StatelessWidget {
  const WeekDayColumn({
    super.key,
    required this.date,
    required this.events,
    required this.selected,
    required this.activeProfileId,
    this.colorFilter = const {},
    this.profileSeedColors = const {},
    this.profileNamesById = const {},
    required this.onEditEvent,
    this.onEventUpdated,
    this.onShiftQuickAction,
    this.moveEnabled = false,
    this.onResizeStarted,
    this.onEventResized,
    this.onResizeEnded,
    this.onResizeDragUpdate,
    this.onResizeApplyChanged,
    this.onHourAxisExpand,
    this.showDivider = true,
    this.axis,
    this.allDayBandHeight,
    this.timedScrollController,
    this.lockTimedScroll = false,
    this.showAllDayBand = true,
    this.showTimedGrid = true,
    this.scrollTimedGrid = true,
    this.showHourLabels = true,
    this.paintHourLines = true,
    this.showNowLine = true,
    this.hideEmptyWeekHours = false,
    this.weekHourPaddingBefore = 2,
    this.weekHourPaddingAfter = 1,
    this.forceFullHourAxis = false,
    this.dragSession = WeekDragSession.empty,
    this.onEmptySlotTap,
    this.selectedSlot,
    this.onSelectedSlotChanged,
    this.onLiveMinutesChanged,
  });

  final DateTime date;
  final List<AppEvent> events;
  final bool selected;
  final String activeProfileId;
  final Set<int> colorFilter;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final bool moveEnabled;
  final ValueChanged<int>? onResizeStarted;
  final WeekEventResizeCallback? onEventResized;
  final VoidCallback? onResizeEnded;
  final ValueChanged<Offset>? onResizeDragUpdate;
  final ValueChanged<ValueChanged<Offset>?>? onResizeApplyChanged;
  final ValueChanged<int>? onHourAxisExpand;
  final bool showDivider;
  final WeekHourAxis? axis;
  @Deprecated('all-day lives in padding hours; unused, always treat as 0')
  final double? allDayBandHeight;
  final ScrollController? timedScrollController;
  final bool lockTimedScroll;
  final bool showAllDayBand;
  final bool showTimedGrid;
  final bool scrollTimedGrid;
  final bool showHourLabels;
  final bool paintHourLines;
  final bool showNowLine;
  final bool hideEmptyWeekHours;
  final int weekHourPaddingBefore;
  final int weekHourPaddingAfter;
  final bool forceFullHourAxis;
  final WeekDragSession dragSession;
  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;
  final ValueChanged<int?>? onLiveMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = context.profileHighlight;

    final background = selected
        ? highlight.accentEnd.withValues(alpha: 0.07)
        : null;

    final resolvedAxis =
        axis ??
        WeekHourAxis.fromEvents(
          events: events,
          hideEmptyHours: hideEmptyWeekHours,
          expanded: forceFullHourAxis || selectedSlot != null,
          paddingBefore: weekHourPaddingBefore,
          paddingAfter: weekHourPaddingAfter,
          extraRangeStartMinutes: selectedSlot?.startMinutes,
          extraRangeEndMinutes: selectedSlot?.endMinutes,
        );
    final allDay = weekAllDayEvents(events);
    final timed = [
      for (final event in events)
        if (event.isTimed) event,
    ];

    Widget timedCanvas = WeekTimedDayCanvas(
      date: date,
      axis: resolvedAxis,
      events: timed,
      allDayEvents: showAllDayBand ? allDay : const [],
      activeProfileId: activeProfileId,
      profileSeedColors: profileSeedColors,
      profileNamesById: profileNamesById,
      onEditEvent: onEditEvent,
      moveEnabled: moveEnabled,
      onResizeStarted: onResizeStarted,
      onEventResized: onEventResized,
      onResizeEnded: onResizeEnded,
      onResizeDragUpdate: onResizeDragUpdate,
      onResizeApplyChanged: onResizeApplyChanged,
      onHourAxisExpand: onHourAxisExpand,
      showHourLabels: showHourLabels,
      paintLines: paintHourLines,
      showNowLine: showNowLine,
      dragSession: dragSession,
      onEmptySlotTap: onEmptySlotTap,
      selectedSlot: selectedSlot,
      onSelectedSlotChanged: onSelectedSlotChanged,
      onLiveMinutesChanged: onLiveMinutesChanged,
    );

    // Divider only on the axis-tall canvas so collapse pad doesn't stretch it.
    if (showDivider && showTimedGrid) {
      timedCanvas = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.22),
            ),
          ),
        ),
        child: timedCanvas,
      );
    }

    Widget timedGrid = timedCanvas;
    if (scrollTimedGrid && showTimedGrid) {
      timedGrid = Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewport = constraints.maxHeight;
            return ScrollConfiguration(
              behavior: const AlmanacNoScrollbarBehavior(),
              child: SingleChildScrollView(
                controller: timedScrollController,
                physics: lockTimedScroll
                    ? const NeverScrollableScrollPhysics()
                    : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: timedCanvas,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: showDivider && !showTimedGrid
              ? BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.22))
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (showTimedGrid) timedGrid],
      ),
    );
  }
}

class WeekAllDayBand extends StatelessWidget {
  const WeekAllDayBand({
    super.key,
    required this.date,
    required this.events,
    required this.activeProfileId,
    required this.profileSeedColors,
    required this.profileNamesById,
    required this.onEditEvent,
    this.moveEnabled = false,
    this.dragSession = WeekDragSession.empty,
    this.paintCellChrome = true,
  });

  final DateTime date;
  final List<AppEvent> events;
  final String activeProfileId;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final ValueChanged<AppEvent> onEditEvent;
  final bool moveEnabled;
  final WeekDragSession dragSession;
  final bool paintCellChrome;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final inset = kWeekHourCellInset;
    final stack = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const SizedBox(height: kWeekHourAllDayGap),
          SizedBox(
            height: kWeekHourAllDayTileHeight,
            child: _WeekDraggableHourTile(
              date: date,
              event: events[i],
              activeProfileId: activeProfileId,
              profileSeedColor: events[i].contextProfileId == null
                  ? null
                  : profileSeedColors[events[i].contextProfileId],
              profileLabel: events[i].contextProfileId == null
                  ? null
                  : profileNamesById[events[i].contextProfileId],
              onTap: () => onEditEvent(events[i]),
              moveEnabled: moveEnabled,
              dragSession: dragSession,
            ),
          ),
        ],
      ],
    );
    if (!paintCellChrome) {
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
        child: stack,
      );
    }
    return Padding(
      padding: EdgeInsets.all(inset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AlmanacRadius.sm),
        ),
        child: Padding(padding: const EdgeInsets.all(4), child: stack),
      ),
    );
  }
}

class WeekTimedDayCanvas extends StatefulWidget {
  const WeekTimedDayCanvas({
    super.key,
    required this.date,
    required this.axis,
    required this.events,
    this.allDayEvents = const [],
    required this.activeProfileId,
    required this.profileSeedColors,
    required this.profileNamesById,
    required this.onEditEvent,
    this.moveEnabled = false,
    this.onResizeStarted,
    this.onEventResized,
    this.onResizeEnded,
    this.onResizeDragUpdate,
    this.onResizeApplyChanged,
    this.onHourAxisExpand,
    this.showHourLabels = false,
    this.paintLines = true,
    this.showNowLine = true,
    this.dragSession = WeekDragSession.empty,
    this.onEmptySlotTap,
    this.selectedSlot,
    this.onSelectedSlotChanged,
    this.onLiveMinutesChanged,
  });

  final DateTime date;
  final WeekHourAxis axis;
  final List<AppEvent> events;
  final List<AppEvent> allDayEvents;
  final String activeProfileId;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final ValueChanged<AppEvent> onEditEvent;
  final bool moveEnabled;
  final ValueChanged<int>? onResizeStarted;
  final WeekEventResizeCallback? onEventResized;
  final VoidCallback? onResizeEnded;
  final ValueChanged<Offset>? onResizeDragUpdate;
  final ValueChanged<ValueChanged<Offset>?>? onResizeApplyChanged;
  final ValueChanged<int>? onHourAxisExpand;
  final bool showHourLabels;
  final bool paintLines;
  final bool showNowLine;
  final WeekDragSession dragSession;
  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;
  final ValueChanged<int?>? onLiveMinutesChanged;

  @override
  State<WeekTimedDayCanvas> createState() => _WeekTimedDayCanvasState();
}

class _WeekTimedDayCanvasState extends State<WeekTimedDayCanvas> {
  String? _resizeEventId;
  int? _resizeStart;
  int? _resizeEnd;
  var _resizeStartEdge = true;
  var _resizingSlot = false;
  double? _emptyTapY;

  @override
  void dispose() {
    widget.onResizeApplyChanged?.call(null);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeekTimedDayCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final armedId = widget.dragSession.armedEventId;
    if (armedId == oldWidget.dragSession.armedEventId) return;
    if (_resizeEventId != null || _resizingSlot) return;
    // Defer: parent may still be building (carousel itemBuilder).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.dragSession.armedEventId != armedId) return;
      if (armedId == null) {
        widget.onLiveMinutesChanged?.call(null);
        return;
      }
      final event = widget.events
          .where((item) => item.id == armedId)
          .firstOrNull;
      if (event != null) {
        widget.onLiveMinutesChanged?.call(eventStartMinutesOfDay(event));
      }
    });
  }

  List<WeekTimedPlacement> get _placements {
    final packed = packWeekTimedEvents(widget.events);
    packed.sort((a, b) => a.columnIndex.compareTo(b.columnIndex));
    if (_resizeEventId == null) return packed;
    return [
      for (final placement in packed)
        if (placement.event.id == _resizeEventId)
          WeekTimedPlacement(
            event: placement.event,
            startMinutes: _resizeStart ?? placement.startMinutes,
            endMinutes: _resizeEnd ?? placement.endMinutes,
            columnIndex: placement.columnIndex,
            columnCount: placement.columnCount,
          )
        else
          placement,
    ];
  }

  void _notifyLiveMinutes() {
    final live = (_resizeEventId != null || _resizingSlot)
        ? (_resizeStartEdge ? _resizeStart : _resizeEnd)
        : null;
    widget.onLiveMinutesChanged?.call(live);
  }

  void _beginSlotResize({required bool startEdge}) {
    final slot = widget.selectedSlot;
    if (slot == null || !slot.isOnDate(widget.date)) return;
    final pin = startEdge ? slot.startMinutes : slot.endMinutes;
    widget.onHourAxisExpand?.call(pin);
    widget.onResizeStarted?.call(pin);
    widget.onResizeApplyChanged?.call(_reapplyResizeAtGlobal);
    setState(() {
      _resizingSlot = true;
      _resizeEventId = null;
      _resizeStart = slot.startMinutes;
      _resizeEnd = slot.endMinutes;
      _resizeStartEdge = startEdge;
    });
    _notifyLiveMinutes();
  }

  void _beginResize(AppEvent event, {required bool startEdge}) {
    final start = eventStartMinutesOfDay(event);
    final end = eventDisplayEndMinutesOfDay(event);
    widget.onResizeStarted?.call(startEdge ? start : end);
    widget.onResizeApplyChanged?.call(_reapplyResizeAtGlobal);
    setState(() {
      _resizeEventId = event.id;
      _resizeStart = start;
      _resizeEnd = end;
      _resizeStartEdge = startEdge;
      _resizingSlot = false;
    });
    _notifyLiveMinutes();
  }

  void _reapplyResizeAtGlobal(Offset global) {
    _updateResizeAtGlobal(global, notifyParent: false);
  }

  double? _localY(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global).dy;
  }

  void _updateResizeAtGlobal(Offset global, {bool notifyParent = true}) {
    if (_resizeEventId == null && !_resizingSlot) return;
    final y = _localY(global);
    if (y == null) return;
    final start = _resizeStart ?? 0;
    final end = _resizeEnd ?? start + kWeekTimeSnapMinutes;
    final next = widget.axis.snapMinutesForY(y);
    setState(() {
      if (_resizeStartEdge) {
        _resizeStart = next.clamp(0, end - kWeekTimeSnapMinutes);
      } else {
        _resizeEnd = next.clamp(start + kWeekTimeSnapMinutes, 24 * 60);
      }
    });
    if (_resizingSlot) {
      widget.onSelectedSlotChanged?.call(
        WeekGridSlot(
          date: widget.date,
          startMinutes: _resizeStart ?? start,
          endMinutes: _resizeEnd ?? end,
        ),
      );
    }
    _notifyLiveMinutes();
    if (notifyParent) {
      widget.onResizeDragUpdate?.call(global);
    }
  }

  void _finishResize() {
    if (_resizeEventId == null && !_resizingSlot) return;
    final id = _resizeEventId;
    final start = _resizeStart;
    final end = _resizeEnd;
    final resizingSlot = _resizingSlot;
    final event = widget.events.where((item) => item.id == id).firstOrNull;
    widget.onResizeApplyChanged?.call(null);
    setState(() {
      _resizeEventId = null;
      _resizeStart = null;
      _resizeEnd = null;
      _resizingSlot = false;
    });
    if (resizingSlot && start != null && end != null) {
      widget.onSelectedSlotChanged?.call(
        WeekGridSlot(date: widget.date, startMinutes: start, endMinutes: end),
      );
    } else if (event != null && start != null && end != null) {
      widget.onEventResized?.call(event, start, end);
    }
    widget.onResizeEnded?.call();
    widget.onLiveMinutesChanged?.call(null);
  }

  void _onEmptyTap() {
    final y = _emptyTapY;
    _emptyTapY = null;
    if (widget.dragSession.armedEventId != null) {
      widget.dragSession.onBackgroundTap?.call();
    }
    if (y == null) return;
    final raw = widget.axis.minutesForY(y);
    final existing = widget.selectedSlot;
    if (existing != null) {
      final duration = (existing.endMinutes - existing.startMinutes).clamp(
        kWeekTimeSnapMinutes,
        24 * 60,
      );
      final start = weekHourFloorMinutes(raw).clamp(0, 24 * 60 - duration);
      final slot = existing.movedTo(date: widget.date, startMinutes: start);
      widget.onSelectedSlotChanged?.call(slot);
      widget.onHourAxisExpand?.call(slot.startMinutes);
      return;
    }
    final time = timeOfDayFromMinutes(weekHourFloorMinutes(raw));
    final slot = WeekGridSlot.fromTap(widget.date, time);
    widget.onSelectedSlotChanged?.call(slot);
    widget.onHourAxisExpand?.call(slot.startMinutes);
    widget.onEmptySlotTap?.call(widget.date, time);
  }

  List<Widget> _allDayInExtraHours(double width) {
    final allDay = widget.allDayEvents;
    if (allDay.isEmpty) return const [];
    final occupied = occupiedHourSlots(widget.events);
    final reserve = weekAllDayReserveHours(
      allDay.length,
      hourHeight: widget.axis.hourHeight,
    );
    final host = weekAllDayHostSegments(
      axis: widget.axis,
      occupiedHours: occupied,
      reserveCount: reserve,
    );
    if (host.isEmpty) return const [];
    final top = host.first.y;
    final inset = kWeekHourCellInset;
    final contentHeight =
        inset +
        allDay.length * kWeekHourAllDayTileHeight +
        (allDay.length - 1) * kWeekHourAllDayGap;
    final hostSpan = host.last.y + host.last.height - top;
    final bandHeight = contentHeight > hostSpan ? contentHeight : hostSpan;
    return [
      Positioned(
        top: top,
        left: 0,
        width: width,
        height: bandHeight,
        child: WeekAllDayBand(
          date: widget.date,
          events: allDay,
          activeProfileId: widget.activeProfileId,
          profileSeedColors: widget.profileSeedColors,
          profileNamesById: widget.profileNamesById,
          onEditEvent: widget.onEditEvent,
          moveEnabled: widget.moveEnabled,
          dragSession: widget.dragSession,
          paintCellChrome: false,
        ),
      ),
    ];
  }

  void _offerMove(BuildContext context, PointerDownEvent event, WeekMoveCandidate candidate) {
    if (!widget.moveEnabled) return;
    final move = WeekMoveScope.maybeOf(context);
    move?.offer(
      pointer: event.pointer,
      global: event.position,
      candidate: candidate,
    );
  }

  bool _hideSlotWhileDragging(WeekMoveController? move, WeekGridSlot slot) {
    return move?.active == true && move!.draggingSlot == slot;
  }

  bool _hideArmedWhileDragging(WeekMoveController? move, AppEvent event) {
    return move?.active == true && move!.draggingEvent?.id == event.id;
  }

  @override
  Widget build(BuildContext context) {
    final placements = _placements;
    final move = WeekMoveScope.maybeOf(context);

    return SizedBox(
      height: widget.axis.totalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final slot = widget.selectedSlot;
          final showSlot = slot != null && slot.isOnDate(widget.date);
          final slotStart = showSlot
              ? (_resizingSlot
                    ? (_resizeStart ?? slot.startMinutes)
                    : slot.startMinutes)
              : 0;
          final slotEnd = showSlot
              ? (_resizingSlot
                    ? (_resizeEnd ?? slot.endMinutes)
                    : slot.endMinutes)
              : 0;
          final armed = _armedPlacement(placements);
          // Keep slot/armed mounted while dragging so the pointer Listener
          // stays in the original hit-test; hide them so only the timed
          // viewport overlay shows the landing contour.
          final paintSlot = showSlot;
          final paintArmed = !showSlot && armed != null;
          final hideSlotWhileDragging =
              showSlot && _hideSlotWhileDragging(move, slot);
          final hideArmedWhileDragging =
              armed != null && _hideArmedWhileDragging(move, armed.event);
          final liveMinutes = (_resizeEventId != null || _resizingSlot)
              ? (_resizeStartEdge ? _resizeStart : _resizeEnd)
              : (armed != null ? armed.startMinutes : null);
          final accent = Theme.of(context).colorScheme.primary;
          // Lower cascade columns first so higher index paints on top.
          final ordered = [...placements]
            ..sort((a, b) => a.columnIndex.compareTo(b.columnIndex));
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.paintLines)
                Positioned.fill(child: WeekHourGridLines(axis: widget.axis)),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapDown: (details) => _emptyTapY = details.localPosition.dy,
                  onTap: _onEmptyTap,
                ),
              ),
              ..._allDayInExtraHours(width),
              for (final placement in ordered) _tileFor(placement, width),
              // Now-line above tiles, below selection handles.
              if (widget.showNowLine)
                Positioned.fill(
                  child: IgnorePointer(
                    child: WeekNowLine(axis: widget.axis, date: widget.date),
                  ),
                ),
              if (paintSlot)
                Positioned.fill(
                  child: Opacity(
                    opacity: hideSlotWhileDragging ? 0 : 1,
                    child: WeekSelectionFrame(
                      axis: widget.axis,
                      startMinutes: slotStart,
                      endMinutes: slotEnd,
                      color: accent,
                      fillAlpha: WeekUiTokens.slotFillAlpha,
                      borderWidth: WeekUiTokens.slotBorderWidth,
                      liveMinutes: liveMinutes,
                      dragSlot: widget.moveEnabled ? slot : null,
                      dragging: hideSlotWhileDragging,
                      onBodyPointerDown: widget.moveEnabled
                          ? (event) => _offerMove(
                                context,
                                event,
                                weekMoveCandidateForSlot(slot),
                              )
                          : null,
                      onStartHandleDrag: (details) {
                        if (!_resizingSlot) {
                          _beginSlotResize(startEdge: true);
                        }
                        _updateResizeAtGlobal(details.globalPosition);
                      },
                      onEndHandleDrag: (details) {
                        if (!_resizingSlot) {
                          _beginSlotResize(startEdge: false);
                        }
                        _updateResizeAtGlobal(details.globalPosition);
                      },
                      onHandleDragEnd: _finishResize,
                    ),
                  ),
                ),
              if (paintArmed)
                Positioned.fill(
                  child: Opacity(
                    opacity: hideArmedWhileDragging ? 0 : 1,
                    child: WeekSelectionFrame(
                      axis: widget.axis,
                      startMinutes: armed.startMinutes,
                      endMinutes: armed.endMinutes,
                      color: accent,
                      fillAlpha: WeekUiTokens.armedFillAlpha,
                      borderWidth: WeekUiTokens.armedBorderWidth,
                      liveMinutes: liveMinutes,
                      dragging: hideArmedWhileDragging,
                      dragEvent: widget.moveEnabled ? armed.event : null,
                      onBodyPointerDown: widget.moveEnabled
                          ? (event) => _offerMove(
                                context,
                                event,
                                weekMoveCandidateForArmedEvent(armed.event),
                              )
                          : null,
                      onStartHandleDrag: widget.onEventResized == null
                          ? null
                          : (details) {
                              if (_resizeEventId != armed.event.id) {
                                _beginResize(armed.event, startEdge: true);
                              }
                              _updateResizeAtGlobal(details.globalPosition);
                            },
                      onEndHandleDrag: widget.onEventResized == null
                          ? null
                          : (details) {
                              if (_resizeEventId != armed.event.id) {
                                _beginResize(armed.event, startEdge: false);
                              }
                              _updateResizeAtGlobal(details.globalPosition);
                            },
                      onHandleDragEnd: widget.onEventResized == null
                          ? null
                          : _finishResize,
                    ),
                  ),
                ),
              // Must be Positioned: a loose WeekHourLabels child would shrink
              // the Stack to the label gutter width, so overflowing tiles paint
              // but do not receive taps (Clip.none).
              if (widget.showHourLabels)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: weekHourLabelSlotWidth(widget.axis.hourHeight),
                  child: WeekHourLabels(
                    axis: widget.axis,
                    liveMinutes: liveMinutes,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tileFor(WeekTimedPlacement placement, double width) {
    final top = widget.axis.yForMinutes(placement.startMinutes);
    final bottom = widget.axis.yForMinutes(placement.endMinutes);
    final height = (bottom - top).clamp(
      kWeekHourMinEventHeight,
      double.infinity,
    );
    // Full column width: fill paints square cells edge-to-edge (overlap indent only).
    final left = placement.leftPx(width);
    final tileWidth = placement.widthPx(width);
    final contentMaxWidth = placement.visibleTextWidthPx(width);
    final armed = widget.dragSession.isArmed(placement.event.id);

    return Positioned(
      top: top,
      left: left,
      width: tileWidth.clamp(12, width),
      height: height,
      child: _WeekDraggableHourTile(
        date: widget.date,
        event: placement.event,
        axis: widget.axis,
        startMinutes: placement.startMinutes,
        endMinutes: placement.endMinutes,
        contentMaxWidth: contentMaxWidth,
        activeProfileId: widget.activeProfileId,
        profileSeedColor: placement.event.contextProfileId == null
            ? null
            : widget.profileSeedColors[placement.event.contextProfileId],
        profileLabel: placement.event.contextProfileId == null
            ? null
            : widget.profileNamesById[placement.event.contextProfileId],
        onTap: () {
          if (armed || widget.dragSession.onArmed == null) {
            widget.onEditEvent(placement.event);
          } else {
            widget.onSelectedSlotChanged?.call(null);
            widget.dragSession.onArmed!(placement.event);
          }
        },
        moveEnabled: widget.moveEnabled,
        dragSession: widget.dragSession,
      ),
    );
  }

  WeekTimedPlacement? _armedPlacement(List<WeekTimedPlacement> placements) {
    final id = widget.dragSession.armedEventId;
    if (id == null) return null;
    return placements.where((item) => item.event.id == id).firstOrNull;
  }
}

class _WeekDraggableHourTile extends StatefulWidget {
  const _WeekDraggableHourTile({
    required this.date,
    required this.event,
    required this.activeProfileId,
    required this.onTap,
    required this.moveEnabled,
    this.axis,
    this.startMinutes,
    this.endMinutes,
    this.contentMaxWidth,
    this.profileSeedColor,
    this.profileLabel,
    this.dragSession = WeekDragSession.empty,
  });

  final DateTime date;
  final AppEvent event;
  final WeekHourAxis? axis;
  final int? startMinutes;
  final int? endMinutes;
  final double? contentMaxWidth;
  final String activeProfileId;
  final VoidCallback onTap;
  final bool moveEnabled;
  final Color? profileSeedColor;
  final String? profileLabel;
  final WeekDragSession dragSession;

  @override
  State<_WeekDraggableHourTile> createState() => _WeekDraggableHourTileState();
}

class _WeekDraggableHourTileState extends State<_WeekDraggableHourTile>
    with SingleTickerProviderStateMixin {
  static const _moveSlop = 12.0;

  Offset? _pointerDown;
  late final AnimationController _shake;

  bool get _lockedByOther =>
      widget.dragSession.isLockedByOther(widget.event.id);

  bool get _armed => widget.dragSession.isArmed(widget.event.id);

  bool get _showLock => weekEventShowsLock(
    widget.event,
    lockedByOther: _lockedByOther,
    armed: _armed,
  );

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _shakeLocked() {
    HapticFeedback.selectionClick();
    _shake.forward(from: 0);
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDown = event.position;
    if (!widget.moveEnabled) return;
    final move = WeekMoveScope.maybeOf(context);
    if (move == null || move.active) return;
    final candidate = weekMoveCandidateForEvent(
      event: widget.event,
      session: widget.dragSession,
    );
    if (candidate == null) return;
    move.offer(
      pointer: event.pointer,
      global: event.position,
      candidate: candidate,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.moveEnabled) return;
    final move = WeekMoveScope.maybeOf(context);
    if (move == null || move.active) return;
    final origin = _pointerDown;
    if (origin == null) return;
    if ((event.position - origin).distance <= _moveSlop) return;
    if (!weekMoveShouldShakeOnSlop(
      event: widget.event,
      session: widget.dragSession,
    )) {
      return;
    }
    _pointerDown = null;
    move.clearOffer(event.pointer);
    _shakeLocked();
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointerDown = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDown = null;
  }

  Widget _buildTile(WeekMoveController? move) {
    final tile = WeekHourEventTile(
      key: ValueKey(
        'week-hour-${widget.date.toIso8601String()}-${widget.event.id}',
      ),
      event: widget.event,
      axis: widget.axis,
      startMinutes: widget.startMinutes,
      endMinutes: widget.endMinutes,
      contentMaxWidth: widget.contentMaxWidth,
      activeProfileId: widget.activeProfileId,
      profileSeedColor: widget.profileSeedColor,
      profileLabel: widget.profileLabel,
      onTap: widget.onTap,
      locked: _showLock,
      armed: _armed,
    );

    final dragging = move?.active == true &&
        move!.draggingEvent?.id == widget.event.id;
    final content = dragging
        ? Opacity(
            opacity: WeekUiTokens.draggingSourceOpacity,
            child: tile,
          )
        : tile;

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = t == 0 || t == 1
              ? 0.0
              : math.sin(t * math.pi * 8) * 5 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: content,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final move = WeekMoveScope.maybeOf(context);
    if (move == null) return _buildTile(null);
    return ListenableBuilder(
      listenable: move,
      builder: (context, _) => _buildTile(move),
    );
  }
}
