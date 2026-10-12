part of '../agenda_view.dart';

mixin _AgendaScrollLogic
    on ConsumerState<AgendaCalendarView>, _AgendaScrollHelpers {
  @override
  void _updateTodayChipVisibility() {
    if (!mounted) return;

    final today = DateTime.now();
    final isCurrentMonth =
        widget.focusedMonth.year == today.year &&
        widget.focusedMonth.month == today.month;

    if (!isCurrentMonth) {
      _setShowTodayChip(true);
      return;
    }

    final agendaDays = _agendaDays();
    if (!_scrollController.hasClients) {
      _scheduleToolbarSync();
      return;
    }

    _setShowTodayChip(!_isTodayInViewport(agendaDays));
  }

  @override
  void _scheduleMaybeScrollToSelectedDay({bool freshMount = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeScrollToSelectedDay(freshMount: freshMount);
    });
  }

  void _maybeScrollToSelectedDay({bool freshMount = false}) {
    if (!_agendaScrollPending()) return;
    if (_scrollToTodayInProgress) return;

    _scrollToSelectedDay(
      layoutSettleFrames: freshMount
          ? _AgendaCalendarViewState._scrollToTodayMonthSettleFrames
          : _AgendaCalendarViewState._scrollToTodayLayoutSettleFrames,
    );
  }

  void _scrollToSelectedDay({
    int layoutSettleFrames =
        _AgendaCalendarViewState._scrollToTodayLayoutSettleFrames,
  }) {
    _userScrolling = false;
    _snapInProgress = false;
    _scrollToTodayInProgress = true;
    _scrollToSelectedAttempt = 0;
    _scrollPerformScheduled = false;
    _ignoreNextCollapseAnchor = true;
    _scheduleScrollToSelectedDay(layoutSettleFrames: layoutSettleFrames);
  }

  void _scheduleScrollToSelectedDay({
    int layoutSettleFrames =
        _AgendaCalendarViewState._scrollToTodayLayoutSettleFrames,
  }) {
    void settleThenScroll([int framesLeft = 0]) {
      if (!mounted || !_scrollToTodayInProgress) return;

      if (framesLeft > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          settleThenScroll(framesLeft - 1);
        });
        return;
      }

      _performScrollToSelectedDay();
    }

    void beginScroll(List<DateTime> agendaDays) {
      _focusSelectedDayOnly(agendaDays);
      _jumpToEstimatedSelectedDay(agendaDays);
      settleThenScroll(layoutSettleFrames);
    }

    if (_isScrollReady()) {
      final agendaDays = _agendaDays();
      if (agendaDays.isEmpty) {
        _finishScrollToSelectedDay(hideTodayChip: true);
        return;
      }
      beginScroll(agendaDays);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollToTodayInProgress) return;

      final agendaDays = _agendaDays();
      if (agendaDays.isEmpty) {
        _finishScrollToSelectedDay(hideTodayChip: true);
        return;
      }

      beginScroll(agendaDays);
    });
  }

  @override
  void _schedulePerformScrollToSelectedDay() {
    if (_scrollPerformScheduled || !_scrollToTodayInProgress) return;
    _scrollPerformScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollPerformScheduled = false;
      if (!mounted || !_scrollToTodayInProgress) return;
      _performScrollToSelectedDay();
    });
  }

  void _retryScrollToSelectedDay() {
    if (_scrollToSelectedAttempt >=
        _AgendaCalendarViewState._maxScrollToTodayAttempts) {
      // Снимаем pending даже при неудаче — иначе каждый скролл снова
      // запускает jumpTo и список «замораживается» на дне.
      _finishScrollToSelectedDay(hideTodayChip: false);
      return;
    }
    _schedulePerformScrollToSelectedDay();
  }

  @override
  double _estimatedScrollOffsetForDay(
    DateTime target,
    List<DateTime> agendaDays,
    Map<DateTime, List<AppEvent>> eventsIndex, {
    bool assumeFocusSelectedDayOnly = false,
  }) {
    bool isCollapsed(DateTime day) {
      if (assumeFocusSelectedDayOnly) {
        return !isSameCalendarDay(day, widget.selectedDate);
      }
      return _isDayCollapsed(day);
    }

    return estimateAgendaDayScrollOffset(
      days: agendaDays,
      target: target,
      isCollapsed: isCollapsed,
      eventCount: (day) => eventsForDay(eventsIndex, day).length,
      firstSectionTopInset: _AgendaCalendarViewState._daySectionPadding.top,
      sectionTopInset:
          _AgendaCalendarViewState._daySectionPadding.top + AlmanacSpacing.sm,
      sectionBottomInset: _AgendaCalendarViewState._daySectionPadding.bottom,
      headerToEventsGap: AlmanacSpacing.xxs,
      eventGap: 6,
    );
  }

  Future<bool> _scrollTargetDayToTop(
    DateTime target,
    List<DateTime> agendaDays,
    Map<DateTime, List<AppEvent>> eventsIndex,
  ) async {
    if (!_isScrollReady()) return false;

    final position = _scrollController.position;
    final exactOffset = _dayHeaderScrollOffset(target);
    final jumpTarget =
        exactOffset ??
        _estimatedScrollOffsetForDay(target, agendaDays, eventsIndex);
    final clamped = jumpTarget.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((clamped - _scrollController.offset).abs() > 1) {
      _scrollController.jumpTo(clamped);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollToTodayInProgress) return false;
    }

    if (_isDayHeaderAsCloseAsPossible(target)) {
      return true;
    }

    final refinedOffset = _dayHeaderScrollOffset(target);
    if (refinedOffset != null &&
        (refinedOffset - _scrollController.offset).abs() > 1) {
      _scrollController.jumpTo(
        refinedOffset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollToTodayInProgress) return false;
    }

    if (_isDayHeaderAsCloseAsPossible(target)) {
      return true;
    }

    final headerKey = _headerKeyFor(target);
    if (headerKey.currentContext != null) {
      await agendaEnsureDayHeaderVisible(headerKey, duration: Duration.zero);
      await WidgetsBinding.instance.endOfFrame;
    }

    return _isDayHeaderAsCloseAsPossible(target);
  }

  Future<void> _performScrollToSelectedDay() async {
    if (!mounted || !_scrollToTodayInProgress || _scrollPerformRunning) return;
    _scrollPerformRunning = true;
    _scrollToSelectedAttempt++;

    try {
      final agendaDays = _agendaDays();
      if (agendaDays.isEmpty) {
        _finishScrollToSelectedDay(hideTodayChip: true);
        return;
      }

      final target = resolveAgendaTodayScrollTarget(
        daysWithEvents: agendaDays,
        today: calendarDayKey(widget.selectedDate),
      );
      if (target == null) {
        _finishScrollToSelectedDay(hideTodayChip: true);
        return;
      }

      if (!_isScrollReady()) {
        _retryScrollToSelectedDay();
        return;
      }

      final eventsIndex = _eventsIndexCache.of(widget.events);
      final aligned = await _scrollTargetDayToTop(
        target,
        agendaDays,
        eventsIndex,
      );
      if (!mounted || !_scrollToTodayInProgress) return;

      if (aligned) {
        _finishScrollToSelectedDay(hideTodayChip: true);
        return;
      }

      _retryScrollToSelectedDay();
    } finally {
      _scrollPerformRunning = false;
    }
  }

  @override
  void _snapAfterUserScroll() {
    if (_scrollToTodayInProgress ||
        _snapInProgress ||
        !_scrollController.hasClients) {
      return;
    }

    final daysWithEvents = _currentDaysWithEvents();
    if (daysWithEvents.isEmpty) return;

    final snapDay = resolveAgendaDaySnapTarget(
      controller: _scrollController,
      days: daysWithEvents,
      headerKeyFor: _headerKeyFor,
    );
    if (snapDay == null) return;

    _scrollDayToTop(snapDay);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    _attachScrollIdleListener();

    // Пользовательский жест имеет приоритет над авто-прокруткой / пином.
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        notification.depth == 0) {
      _abortAutoScrollForUserGesture();
    }

    if (_agendaScrollPending() &&
        notification.depth == 0 &&
        notification is ScrollMetricsNotification) {
      _scheduleMaybeScrollToSelectedDay();
    }
    if (_scrollToTodayInProgress &&
        notification.depth == 0 &&
        notification is ScrollMetricsNotification) {
      _schedulePerformScrollToSelectedDay();
    }
    if (notification is ScrollEndNotification &&
        notification.depth == 0 &&
        !_snapInProgress &&
        !_scrollToTodayInProgress) {
      _userScrolling = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snapInProgress || _scrollToTodayInProgress) return;
        if (_scrollPosition?.isScrollingNotifier.value == true) return;
        _snapAfterUserScroll();
        if (!_snapInProgress) {
          _updateTodayChipVisibility();
        }
      });
    }
    return false;
  }
}
