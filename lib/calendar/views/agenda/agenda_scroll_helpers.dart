part of '../agenda_view.dart';

mixin _AgendaScrollHelpers on ConsumerState<AgendaCalendarView> {
  late final ScrollController _scrollController;
  final _dayHeaderKeys = <DateTime, GlobalKey>{};
  final _eventsIndexCache = EventDayIndexCache();

  bool _showTodayChip = false;
  bool _snapInProgress = false;
  bool _userScrolling = false;
  var _toolbarSyncScheduled = false;
  ScrollPosition? _scrollPosition;
  bool _ignoreNextCollapseAnchor = false;
  bool _scrollToTodayInProgress = false;
  var _scrollToSelectedAttempt = 0;
  var _scrollPerformScheduled = false;
  var _scrollPerformRunning = false;

  List<DateTime> _agendaDays() => agendaVisibleDays(
    widget.events,
    widget.focusedMonth,
    highlightDay: widget.selectedDate,
    colorFilter: widget.colorFilter,
    eventsIndex: _eventsIndexCache.of(widget.events),
  );

  List<DateTime> _currentDaysWithEvents() => _agendaDays();

  bool _isDayCollapsed(DateTime date) => ref
      .read(agendaCollapseProvider.notifier)
      .isDayCollapsed(_agendaMonthKey, date);

  void _toggleDayCollapsed(DateTime date, List<DateTime> daysWithEvents) {
    _ignoreNextCollapseAnchor = true;
    ref.read(agendaCollapseProvider.notifier).toggleDay(_agendaMonthKey, date);
  }

  void _focusSelectedDayOnly(List<DateTime> daysWithEvents) {
    ref
        .read(agendaCollapseProvider.notifier)
        .focusDayOnly(_agendaMonthKey, daysWithEvents, widget.selectedDate);
  }

  double _estimatedScrollOffsetForSelectedDay(
    List<DateTime> agendaDays, {
    bool assumeFocusSelectedDayOnly = false,
  }) {
    final target = resolveAgendaTodayScrollTarget(
      daysWithEvents: agendaDays,
      today: calendarDayKey(widget.selectedDate),
    );
    if (target == null) return 0;

    final eventsIndex = _eventsIndexCache.of(widget.events);
    return _estimatedScrollOffsetForDay(
      target,
      agendaDays,
      eventsIndex,
      assumeFocusSelectedDayOnly: assumeFocusSelectedDayOnly,
    );
  }

  double _initialScrollOffsetForPendingAgendaScroll() {
    if (!ref.read(calendarNavigationProvider).agendaScrollPending) {
      return 0;
    }

    final agendaDays = _agendaDays();
    if (agendaDays.isEmpty) return 0;

    return _estimatedScrollOffsetForSelectedDay(
      agendaDays,
      assumeFocusSelectedDayOnly: true,
    );
  }

  bool _jumpToEstimatedSelectedDay(List<DateTime> agendaDays) {
    if (!_isScrollReady()) return false;

    final jumpTarget = _estimatedScrollOffsetForSelectedDay(agendaDays);
    final position = _scrollController.position;
    final clamped = jumpTarget.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - _scrollController.offset).abs() > 1) {
      _scrollController.jumpTo(clamped);
    }
    return true;
  }

  /// Пользователь начал жест — отменяем незавершённый scroll-to-day.
  void _abortAutoScrollForUserGesture() {
    if (_scrollToTodayInProgress || _agendaScrollPending()) {
      _snapInProgress = false;
      _finishScrollToSelectedDay(hideTodayChip: false);
    }
  }

  void _finishScrollToSelectedDay({required bool hideTodayChip}) {
    _scrollToTodayInProgress = false;
    _scrollToSelectedAttempt = 0;
    _scrollPerformScheduled = false;
    _scrollPerformRunning = false;
    // Всегда снимаем pending — иначе при неудачном выравнивании
    // каждый жест снова запускает jumpTo и ломает прокрутку.
    ref.read(calendarNavigationProvider.notifier).clearAgendaScrollPending();
    if (hideTodayChip) {
      _hideTodayChip();
    } else {
      _updateTodayChipVisibility();
    }
  }

  bool _agendaScrollPending() =>
      ref.read(calendarNavigationProvider).agendaScrollPending;

  double? _dayHeaderScrollOffset(DateTime day) {
    return agendaDayHeaderScrollOffset(_headerKeyFor(day), _scrollController);
  }

  bool _isDayHeaderAlignedAtTop(DateTime day) {
    if (!_scrollController.hasClients) return false;

    final headerTop = agendaDayHeaderViewportTop(
      _headerKeyFor(day),
      _scrollController,
    );
    return headerTop != null && headerTop.abs() <= agendaDaySnapAlignTolerance;
  }

  /// День у верхнего края, либо уже на ближайшем достижимом offset
  /// (короткий список / конец месяца — выровнять точно нельзя).
  bool _isDayHeaderAsCloseAsPossible(DateTime day) {
    if (_isDayHeaderAlignedAtTop(day)) return true;
    if (!_isScrollReady()) return false;

    final targetOffset = _dayHeaderScrollOffset(day);
    if (targetOffset == null) return false;
    return (targetOffset - _scrollController.offset).abs() <=
        agendaDaySnapAlignTolerance;
  }

  bool _isScrollReady() =>
      _scrollController.hasClients && _scrollController.position.haveDimensions;

  void _completeDayHeaderScroll({bool hideTodayChipOnComplete = false}) {
    if (hideTodayChipOnComplete) {
      _hideTodayChip();
    } else {
      _updateTodayChipVisibility();
    }
  }

  bool _scrollDayHeaderToTop(
    DateTime day, {
    bool animate = true,
    bool hideTodayChipOnComplete = false,
  }) {
    if (!_scrollController.hasClients) return false;

    final offset = _dayHeaderScrollOffset(day);
    if (offset == null) return false;

    void onComplete() {
      if (!mounted) return;
      _snapInProgress = false;
      if (_scrollToTodayInProgress) {
        _scrollToTodayInProgress = false;
      }
      _completeDayHeaderScroll(
        hideTodayChipOnComplete: hideTodayChipOnComplete,
      );
    }

    if (_isDayHeaderAsCloseAsPossible(day) ||
        (offset - _scrollController.offset).abs() <= 1) {
      onComplete();
      return true;
    }

    _snapInProgress = true;
    if (animate) {
      final distance = (offset - _scrollController.offset).abs();
      _scrollController
          .animateTo(
            offset,
            duration: agendaDayAttractDuration(distance: distance),
            curve: AlmanacCurves.snap,
          )
          .whenComplete(onComplete);
    } else {
      _scrollController.jumpTo(offset);
      onComplete();
    }
    return true;
  }

  void _onCollapseStateChanged() {
    if (_scrollToTodayInProgress || _agendaScrollPending()) {
      if (_ignoreNextCollapseAnchor) {
        _ignoreNextCollapseAnchor = false;
      }
      return;
    }

    if (_ignoreNextCollapseAnchor) {
      _ignoreNextCollapseAnchor = false;
      return;
    }

    if (_userScrolling || _snapInProgress) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _userScrolling ||
          _snapInProgress ||
          _scrollToTodayInProgress) {
        return;
      }
      _snapAfterUserScroll();
    });
  }

  void _scrollDayToTop(
    DateTime day, {
    bool animate = true,
    bool hideTodayChipOnComplete = false,
  }) {
    _scrollDayHeaderToTop(
      day,
      animate: animate,
      hideTodayChipOnComplete: hideTodayChipOnComplete,
    );
  }

  void _hideTodayChip() {
    _setShowTodayChip(false);
  }

  void _onScrollControllerChanged() {
    if (!_agendaScrollPending()) return;
    if (_scrollToTodayInProgress) {
      if (_isScrollReady()) {
        _schedulePerformScrollToSelectedDay();
      }
      return;
    }
    if (_isScrollReady()) {
      _scheduleMaybeScrollToSelectedDay();
    }
  }

  void _attachScrollIdleListener() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (identical(_scrollPosition, position)) return;

    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollIdleChanged);
    _scrollPosition = position;
    position.isScrollingNotifier.addListener(_onScrollIdleChanged);
    if (_scrollToTodayInProgress) {
      _schedulePerformScrollToSelectedDay();
    }
  }

  void _onScrollIdleChanged() {
    final position = _scrollPosition;
    if (position == null || !mounted) return;

    if (position.isScrollingNotifier.value) {
      if (!_snapInProgress) _userScrolling = true;
      return;
    }

    if (_snapInProgress) {
      _userScrolling = false;
      return;
    }

    if (!_userScrolling) return;

    _userScrolling = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _snapInProgress) return;
      _snapAfterUserScroll();
    });
  }

  void _scheduleToolbarSync() {
    if (_toolbarSyncScheduled) return;
    _toolbarSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toolbarSyncScheduled = false;
      if (!mounted) return;
      _publishToolbarState();
    });
  }

  void _setShowTodayChip(bool value) {
    if (_showTodayChip == value) return;
    _showTodayChip = value;
    _publishToolbarState();
  }

  void _publishToolbarState() {
    publishCalendarToolbarViewState(
      ref,
      CalendarToolbarViewState(showToday: _showTodayChip),
    );
  }

  String get _agendaMonthKey => agendaMonthKey(widget.focusedMonth);

  bool _isTodayInViewport(List<DateTime> daysWithEvents) {
    if (!_scrollController.hasClients) return false;

    final todayKey = calendarDayKey(DateTime.now());
    if (!daysWithEvents.any((date) => isSameCalendarDay(date, todayKey))) {
      return false;
    }

    if (isAgendaDayHeaderVisible(_headerKeyFor(todayKey), _scrollController)) {
      return true;
    }

    final topmost = findTopmostAgendaDayHeader(
      controller: _scrollController,
      days: daysWithEvents,
      headerKeyFor: _headerKeyFor,
    );
    return topmost != null && isSameCalendarDay(topmost, todayKey);
  }

  GlobalKey _headerKeyFor(DateTime date) {
    final key = calendarDayKey(date);
    return _dayHeaderKeys.putIfAbsent(key, GlobalKey.new);
  }

  double _estimatedScrollOffsetForDay(
    DateTime target,
    List<DateTime> agendaDays,
    Map<DateTime, List<AppEvent>> eventsIndex, {
    bool assumeFocusSelectedDayOnly = false,
  });

  void _updateTodayChipVisibility();

  void _schedulePerformScrollToSelectedDay();

  // ignore: unused_element_parameter
  void _scheduleMaybeScrollToSelectedDay({bool freshMount = false});

  void _snapAfterUserScroll();
}
