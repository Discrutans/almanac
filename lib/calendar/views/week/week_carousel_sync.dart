part of '../week_view.dart';

/// Прокрутка, snap и смена недели в карусели.
extension _WeekCarouselSync on _WeekCalendarViewState {
  static const _scrollEpsilon = 1.5;

  // --- Даты и видимость «Сегодня» ---

  List<DateTime> _displayDatesForSelected() {
    if (_carousel) {
      return weekCarouselWindowDates(windowStart: _resolvedCarouselWindowStart);
    }
    return WeekCalendarView.weekDays(widget.selectedDate);
  }

  int _selectedDateIndex([List<DateTime>? displayDates]) {
    final dates = displayDates ?? _displayDatesForSelected();
    final index = dates.indexWhere(
      (date) => isSameCalendarDay(date, widget.selectedDate),
    );
    return index < 0 ? 0 : index;
  }

  ScrollController? _carouselPrimaryController() {
    if (_carouselController.hasClients &&
        _carouselController.position.haveDimensions) {
      return _carouselController;
    }
    return null;
  }

  bool _isCarouselScrollReady() =>
      _carousel && _columnWidth > 0 && _carouselPrimaryController() != null;

  bool _isTodayVisibleInWeek(List<DateTime> displayDates) {
    final todayKey = calendarDayKey(DateTime.now());
    final todayIndex = displayDates.indexWhere(
      (date) => isSameCalendarDay(date, todayKey),
    );
    if (todayIndex < 0) return false;
    if (!_carousel) return true;

    final scrollController = _carouselPrimaryController();
    if (scrollController == null || _columnWidth <= 0) return false;

    final lane = weekCarouselLaneIndexForDate(displayDates, todayKey);
    final columnLeft = lane * _columnWidth - scrollController.offset;
    final columnRight = columnLeft + _columnWidth;
    final viewportWidth = scrollController.position.viewportDimension;

    return columnRight > 1 && columnLeft < viewportWidth - 1;
  }

  void _updateTodayChipVisibility(List<DateTime> displayDates) {
    if (!mounted) return;
    final shouldShow = !_isTodayVisibleInWeek(displayDates);
    if (shouldShow == _showTodayChip) return;
    _showTodayChip = shouldShow;
    publishCalendarToolbarViewState(
      ref,
      CalendarToolbarViewState(showToday: _showTodayChip),
    );
  }

  void _updateTodayChipFromScroll() {
    if (!mounted) return;
    _updateTodayChipVisibility(_displayDatesForSelected());
  }

  // --- Планирование прокрутки ---

  void _scheduleCarouselScroll({
    required VoidCallback action,
    int layoutSettleFrames = 0,
    bool requiresCarousel = true,
    void Function()? onSkip,
  }) {
    void attempt([int tries = 0]) {
      if (!mounted) return;

      if (tries < layoutSettleFrames) {
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt(tries + 1));
        return;
      }

      if (requiresCarousel && !_carousel) {
        onSkip?.call();
        return;
      }

      if (_carousel && (_columnWidth <= 0 || !_isCarouselScrollReady())) {
        if (tries < layoutSettleFrames + 32) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => attempt(tries + 1),
          );
        }
        return;
      }

      action();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  void _scheduleScrollToToday({int layoutSettleFrames = 0}) {
    _scheduleCarouselScroll(
      layoutSettleFrames: layoutSettleFrames,
      onSkip: _updateTodayChipFromScroll,
      action: () => _scrollToToday(_displayDatesForSelected(), animate: false),
    );
  }

  void _scheduleCenterSelected({
    required bool animate,
    Duration? duration,
    bool lockWhileAnimating = false,
    int layoutSettleFrames = 0,
  }) {
    _scheduleCarouselScroll(
      layoutSettleFrames: layoutSettleFrames,
      onSkip: () => _needsCenterOnSelected = false,
      action: () {
        _centerSelected(
          animate: animate,
          duration: duration,
          lockWhileAnimating: lockWhileAnimating,
        );
        _needsCenterOnSelected = false;
      },
    );
  }

  void _scrollToToday(List<DateTime> displayDates, {bool animate = true}) {
    if (!_carousel) {
      _updateTodayChipFromScroll();
      return;
    }

    final todayKey = calendarDayKey(DateTime.now());
    final todayIndex = displayDates.indexWhere(
      (date) => isSameCalendarDay(date, todayKey),
    );
    if (todayIndex < 0) return;

    _centerOnDayIndex(todayIndex, animate: animate);
  }

  // --- Позиционирование ---

  double _scrollOffsetForDayIndex(int dayIndex) {
    return weekCarouselScrollOffsetForDayIndex(
      dayIndex: dayIndex,
      columnWidth: _columnWidth,
    );
  }

  void _centerOnDayIndex(
    int dayIndex, {
    required bool animate,
    Duration? duration,
    bool lockWhileAnimating = false,
  }) {
    if (!_carousel || _columnWidth <= 0) return;

    final primary = _carouselPrimaryController();
    if (primary == null ||
        !primary.hasClients ||
        !primary.position.haveDimensions) {
      return;
    }

    final pos = primary.position;
    final target = snapWeekCarouselOffset(
      offset: _scrollOffsetForDayIndex(dayIndex),
      columnWidth: _columnWidth,
      minExtent: pos.minScrollExtent,
      maxExtent: pos.maxScrollExtent,
    );

    _scrollCarouselToOffset(
      target,
      animate: animate,
      duration: duration,
      lockWhileAnimating: lockWhileAnimating,
      onComplete: _updateTodayChipFromScroll,
    );
  }

  void _scrollCarouselToOffset(
    double target, {
    required bool animate,
    Duration? duration,
    bool lockWhileAnimating = false,
    void Function()? onComplete,
  }) {
    final controller = _carouselPrimaryController();
    if (controller == null ||
        !controller.hasClients ||
        !controller.position.haveDimensions) {
      return;
    }

    final clamped = target.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );

    void finish() {
      if (!mounted) return;
      _carouselBusy = false;
      if (_carouselScrollLocked) {
        _rebuild(() => _carouselScrollLocked = false);
      }
      onComplete?.call();
    }

    final distance = (controller.offset - clamped).abs();
    if (distance < 1) {
      finish();
      return;
    }

    _carouselBusy = true;
    if (lockWhileAnimating && !_carouselScrollLocked) {
      _rebuild(() => _carouselScrollLocked = true);
    }

    if (!animate) {
      controller.jumpTo(clamped);
      finish();
      return;
    }

    controller
        .animateTo(
          clamped,
          duration:
              duration ??
              weekCarouselAttractDuration(
                distance: distance,
                columnWidth: _columnWidth,
              ),
          curve: AlmanacCurves.snap,
        )
        .whenComplete(finish);
  }

  bool _isAtScrollOffsetForDay(int dayIndex) {
    final primary = _carouselPrimaryController();
    if (primary == null ||
        !primary.hasClients ||
        !primary.position.haveDimensions) {
      return false;
    }

    final target = _scrollOffsetForDayIndex(dayIndex);
    return (primary.offset - target).abs() < _scrollEpsilon;
  }

  bool _isSelectedDateAlreadyCentered() {
    if (!_carousel || _columnWidth <= 0) return false;
    return _isAtScrollOffsetForDay(_selectedDateIndex());
  }

  void _centerSelected({
    required bool animate,
    Duration? duration,
    bool lockWhileAnimating = false,
  }) {
    if (!_carousel || _columnWidth <= 0) return;
    _centerOnDayIndex(
      _selectedDateIndex(),
      animate: animate,
      duration: duration,
      lockWhileAnimating: lockWhileAnimating,
    );
  }

  WeekDropTarget? _resolveMoveTarget(Offset globalPosition) {
    if (_carousel) {
      return _carouselViewportKey.currentState?.dropTargetAt(globalPosition);
    }
    return _wideGridKey.currentState?.dropTargetAt(globalPosition);
  }

  void _snapCarouselToNearestColumn({bool animate = true}) {
    if (!_carousel || _columnWidth <= 0) return;

    final primary = _carouselPrimaryController();
    if (primary == null || !primary.position.haveDimensions) return;

    final pos = primary.position;
    final target = snapWeekCarouselOffset(
      offset: pos.pixels,
      columnWidth: _columnWidth,
      minExtent: pos.minScrollExtent,
      maxExtent: pos.maxScrollExtent,
    );
    if ((pos.pixels - target).abs() < 0.5) {
      _syncSelectedDateFromScrollOffset(target);
      _updateTodayChipFromScroll();
      return;
    }

    _scrollCarouselToOffset(
      target,
      animate: animate,
      onComplete: () {
        _syncSelectedDateFromScrollOffset(target);
        _updateTodayChipFromScroll();
      },
    );
  }

  // --- Синхронизация выбранной даты ---

  void _syncSelectedDateFromScrollOffset(double offset) {
    if (!_carousel || _columnWidth <= 0 || _carouselBusy) return;

    final displayDates = _displayDatesForSelected();
    final index = weekCarouselDayIndexForScrollOffset(
      offset: offset,
      columnWidth: _columnWidth,
      dayCount: displayDates.length,
    );
    _selectCarouselDay(displayDates[index]);
  }

  void _selectCarouselDay(DateTime date) {
    final callback = widget.onSelectedDateInWeekChanged;
    if (callback == null) return;
    if (isSameCalendarDay(date, widget.selectedDate)) return;
    _selectionFromCarouselScroll = true;
    callback(date);
  }

  bool _isDateVisibleInViewport(DateTime date) {
    if (!_carousel || _columnWidth <= 0) return false;
    final primary = _carouselPrimaryController();
    if (primary == null ||
        !primary.hasClients ||
        !primary.position.haveDimensions) {
      return false;
    }

    final dates = _displayDatesForSelected();
    final lane = weekCarouselLaneIndexForDate(dates, date);
    final columnLeft = lane * _columnWidth - primary.offset;
    final columnRight = columnLeft + _columnWidth;
    final viewportWidth = primary.position.viewportDimension;
    return columnRight > 1 && columnLeft < viewportWidth - 1;
  }

  void _shiftCarouselWindowIfNeeded() {
    if (!_carousel) return;
    if (!weekCarouselWindowNeedsShift(
      windowStart: _resolvedCarouselWindowStart,
      selectedDate: widget.selectedDate,
    )) {
      return;
    }

    final oldStart = _resolvedCarouselWindowStart;
    final newStart = weekCarouselWindowStartFor(widget.selectedDate);
    if (isSameCalendarDay(oldStart, newStart)) return;

    final deltaDays = newStart.difference(oldStart).inDays;
    _carouselWindowStart = newStart;

    final primary = _carouselPrimaryController();
    if (primary != null &&
        primary.hasClients &&
        primary.position.haveDimensions &&
        _columnWidth > 0) {
      primary.position.correctBy(-deltaDays * _columnWidth);
    }
  }

  bool _handleCarouselScrollNotification(ScrollNotification notification) {
    if (!_carousel || _carouselBusy || _weekDragActive) return false;
    if (notification.metrics.axis != Axis.horizontal) return false;

    if (notification is ScrollEndNotification) {
      // Палец ушёл — ballistic-пружина ещё может ехать. Не пересобираем дерево
      // на каждом промежуточном кадре: это рвёт 90/120 Hz.
      if (notification.dragDetails != null) {
        final pixels = notification.metrics.pixels;
        final snapped = snapWeekCarouselOffset(
          offset: pixels,
          columnWidth: _columnWidth,
          minExtent: notification.metrics.minScrollExtent,
          maxExtent: notification.metrics.maxScrollExtent,
        );
        if ((pixels - snapped).abs() < 0.5) {
          _syncSelectedDateFromScrollOffset(pixels);
          _updateTodayChipFromScroll();
        }
        return false;
      }

      _syncSelectedDateFromScrollOffset(notification.metrics.pixels);
      _updateTodayChipFromScroll();
    }

    return false;
  }
}
