import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../state/calendar_toolbar_providers.dart';
import '../../state/calendar_filter_providers.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_card.dart';
import '../../core/ui/almanac_feedback.dart';
import '../calendar_event_index.dart';
import '../calendar_types.dart';
import '../widgets/chrome/calendar_grid_panel.dart';
import '../widgets/chrome/calendar_week_strip.dart';
import '../widgets/chrome/date_cell.dart';
import '../widgets/event_list_item.dart';
import '../widgets/week/week_carousel_snap_physics.dart';
import '../widgets/week/week_carousel_unified.dart';
import '../widgets/week/week_move_types.dart';
import '../widgets/schedule_quick_actions_bar.dart';
import '../widgets/week/week_day_column.dart';
import '../widgets/week/week_events_drop_grid.dart';
import '../widgets/week/week_drag_policy.dart';
import '../widgets/week/week_drop_hit_test.dart';
import '../widgets/week/week_move_controller.dart';
import '../widgets/week/week_hour_axis.dart';
import '../widgets/week/week_grid_slot.dart';
import '../calendar_entry_capabilities.dart';

part 'week/week_carousel_sync.dart';
part 'week/week_events_panel.dart';
part 'week/week_carousel_panel.dart';
part 'week/week_layout.dart';

/// Недельный вид: полоска дат сверху, колонки событий снизу.
///
/// На узких экранах включается «карусель»: даты и события дня в одной колонке,
/// прокручиваются единым горизонтальным скроллом.
class WeekCalendarView extends ConsumerStatefulWidget {
  const WeekCalendarView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    this.onSelectedDateInWeekChanged,
    this.onDateLongPress,
    required this.onEditEvent,
    required this.onDeleteEvent,
    required this.onCreateEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    required this.activeProfileId,
    this.colorFilter = const {},
    this.profileSeedColors = const {},
    this.profileNamesById = const {},
    this.onEventMoved,
    this.onEventResized,
    this.onRefresh,
    this.showWeekDragHint = false,
    this.onWeekDragHintDismissed,
    this.scrollToTodayNonce = 0,
    this.hideEmptyWeekHours = false,
    this.weekHourPaddingBefore = 2,
    this.weekHourPaddingAfter = 1,
    this.weekHourZoomLevel = kWeekHourZoomLevelDefault,
    this.onWeekHourZoomLevelChanged,
    this.lockedByOtherEventIds = const {},
    this.onEmptySlotTap,
    this.selectedSlot,
    this.onSelectedSlotChanged,
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<AppEvent> events;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onSelectedDateInWeekChanged;
  final ValueChanged<DateTime>? onDateLongPress;
  final ValueChanged<AppEvent> onEditEvent;
  final EventDeleteCallback onDeleteEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final String activeProfileId;
  final Set<int> colorFilter;
  final Map<String, Color> profileSeedColors;
  final Map<String, String> profileNamesById;
  final WeekEventMoveCallback? onEventMoved;
  final WeekEventResizeCallback? onEventResized;
  final Future<void> Function()? onRefresh;
  final bool showWeekDragHint;
  final VoidCallback? onWeekDragHintDismissed;
  final int scrollToTodayNonce;
  final bool hideEmptyWeekHours;
  final int weekHourPaddingBefore;
  final int weekHourPaddingAfter;
  final int weekHourZoomLevel;
  final ValueChanged<int>? onWeekHourZoomLevelChanged;
  final Set<String> lockedByOtherEventIds;
  final void Function(DateTime date, TimeOfDay time)? onEmptySlotTap;
  final WeekGridSlot? selectedSlot;
  final ValueChanged<WeekGridSlot?>? onSelectedSlotChanged;

  @override
  ConsumerState<WeekCalendarView> createState() => _WeekCalendarViewState();

  static List<DateTime> weekDays(DateTime date) {
    final start = calendarWeekStartMonday(date);
    return List.generate(7, (index) {
      final day = start.add(Duration(days: index));
      return calendarDayKey(day);
    });
  }
}

class _WeekCalendarViewState extends ConsumerState<WeekCalendarView> {
  /// Горизонтальный padding карточек карусели — учитывается при расчёте ширины колонки.
  static const _carouselCardPadding = EdgeInsets.symmetric(
    vertical: AlmanacSpacing.xs,
  );

  final _carouselController = ScrollController();

  final _carouselViewportKey = GlobalKey<WeekCarouselUnifiedState>();

  final _eventsIndexCache = EventDayIndexCache();

  bool _carouselBusy = false;
  bool _carousel = false;
  double _columnWidth = 0;
  bool _showTodayChip = false;
  var _lastLayoutColumnWidth = 0.0;
  bool _needsCenterOnSelected = true;
  bool _carouselScrollLocked = false;
  late final WeekMoveController _move;
  var _moveWasActive = false;
  final _wideGridKey = GlobalKey<WeekEventsDropGridState>();
  String? _armedEventId;
  bool _selectionFromCarouselScroll = false;
  DateTime? _carouselWindowStart;
  WeekGridSlot? _localSlot;

  bool get _weekDragActive => _move.active;

  WeekGridSlot? get _effectiveSlot =>
      widget.onSelectedSlotChanged != null ? widget.selectedSlot : _localSlot;

  DateTime get _resolvedCarouselWindowStart {
    return _carouselWindowStart ??= weekCarouselWindowStartFor(
      widget.selectedDate,
    );
  }

  @override
  void initState() {
    super.initState();
    _move = WeekMoveController(resolveTarget: _resolveMoveTarget);
    _moveWasActive = _move.active;
    _move.addListener(_onMoveActiveChanged);
    _carouselWindowStart = weekCarouselWindowStartFor(widget.selectedDate);
    // На первом монтировании всегда центрируем выбранный день. scrollToTodayNonce
    // обрабатывается только в didUpdateWidget (кнопка «Сегодня» в уже открытой неделе).
    _needsCenterOnSelected = true;
    _scheduleCenterSelected(animate: false, layoutSettleFrames: 2);
  }

  void _rebuild(VoidCallback fn) => setState(fn);

  WeekDragSession get _weekDragSession => WeekDragSession(
    armedEventId: _armedEventId,
    lockedByOtherIds: widget.lockedByOtherEventIds,
    onArmed: (event) {
      if (!mounted) return;
      _rebuild(() {
        _armedEventId = event.id;
        _localSlot = null;
      });
      widget.onSelectedSlotChanged?.call(null);
    },
    onBackgroundTap: _disarmWeekEvent,
  );

  void _onMoveActiveChanged() {
    final active = _move.active;
    if (active == _moveWasActive) return;
    _moveWasActive = active;
    if (!mounted) return;
    setState(() {
      if (_carousel) {
        _carouselScrollLocked = active;
      }
    });
  }

  void _onMoveResult(WeekMoveResult result) {
    switch (result) {
      case WeekMoveEventMoved(
        :final event,
        :final date,
        :final startTime,
      ):
        if (startTime != null) {
          final pinMinutes = startTime.hour * 60 + startTime.minute;
          _carouselViewportKey.currentState?.retargetViewportPin(pinMinutes);
          _wideGridKey.currentState?.retargetViewportPin(pinMinutes);
        }
        _armedEventId = null;
        widget.onEventMoved?.call(event, date, startTime);
        if (_carousel) {
          _snapCarouselToNearestColumn();
        }
      case WeekMoveSlotMoved(:final slot):
        _carouselViewportKey.currentState?.retargetViewportPin(
          slot.startMinutes,
        );
        _wideGridKey.currentState?.retargetViewportPin(slot.startMinutes);
        _setSlot(slot);
      case WeekMoveRejected():
        unawaited(HapticFeedback.selectionClick());
      case WeekMoveUnchanged():
      case WeekMoveCancelled():
        break;
    }
    if (_move.active) {
      _move.finish();
    }
    if (mounted && _carousel && !_carouselBusy && !_move.active) {
      setState(() => _carouselScrollLocked = false);
    }
  }

  void _setSlot(WeekGridSlot? slot) {
    if (widget.onSelectedSlotChanged != null) {
      if (_armedEventId != null) {
        _rebuild(() {
          _armedEventId = null;
        });
      }
      widget.onSelectedSlotChanged!(slot);
    } else {
      _rebuild(() {
        _localSlot = slot;
        if (slot != null) {
          _armedEventId = null;
        }
      });
    }
    if (slot != null && !isSameCalendarDay(slot.date, widget.selectedDate)) {
      widget.onDateSelected(slot.date);
    }
  }

  void _disarmWeekEvent() {
    if (_armedEventId == null) return;
    _rebuild(() {
      _armedEventId = null;
    });
  }

  bool _sameWeek(DateTime a, DateTime b) {
    return isSameCalendarDay(
      calendarWeekStartMonday(a),
      calendarWeekStartMonday(b),
    );
  }

  @override
  void didUpdateWidget(covariant WeekCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollToTodayNonce != oldWidget.scrollToTodayNonce) {
      final selectedDateChanged = !isSameCalendarDay(
        oldWidget.selectedDate,
        widget.selectedDate,
      );
      _needsCenterOnSelected = false;
      _scheduleScrollToToday(layoutSettleFrames: selectedDateChanged ? 2 : 0);
      return;
    }

    final monthChanged =
        oldWidget.focusedMonth.year != widget.focusedMonth.year ||
        oldWidget.focusedMonth.month != widget.focusedMonth.month;
    final selectedDateChanged = !isSameCalendarDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    );

    if (selectedDateChanged) {
      _shiftCarouselWindowIfNeeded();
      if (!_sameWeek(oldWidget.selectedDate, widget.selectedDate)) {
        _armedEventId = null;
        if (widget.onSelectedSlotChanged == null) {
          _localSlot = null;
        }
      }
    }

    if (monthChanged && !selectedDateChanged) {
      if (!_selectionFromCarouselScroll &&
          !_isDateVisibleInViewport(widget.selectedDate)) {
        _needsCenterOnSelected = true;
        _scheduleCenterSelected(animate: false, layoutSettleFrames: 2);
      }
      return;
    }

    if (selectedDateChanged) {
      final fromScroll = _selectionFromCarouselScroll;
      _selectionFromCarouselScroll = false;

      if (fromScroll) {
        // Прокрутка сама выравнивает колонки; только обновляем активную неделю.
        _needsCenterOnSelected = false;
        return;
      }

      if (_weekDragActive) return;

      if (_isSelectedDateAlreadyCentered()) {
        _needsCenterOnSelected = false;
        return;
      }

      _needsCenterOnSelected = false;
      _scheduleCenterSelected(animate: true, layoutSettleFrames: 1);
    }
  }

  @override
  void dispose() {
    _move.removeListener(_onMoveActiveChanged);
    _carouselController.dispose();
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildWeekLayout(context);
}
