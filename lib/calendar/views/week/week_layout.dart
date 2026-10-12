part of '../week_view.dart';

extension _WeekLayout on _WeekCalendarViewState {
  Widget _buildWeekLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weekDates = WeekCalendarView.weekDays(widget.selectedDate);
    final eventsIndex = _eventsIndexCache.of(widget.events);
    final hasDraggableEvents =
        widget.onEventMoved != null &&
        widget.events.any((event) => event.capabilities.canMoveOnWeekGrid);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = DateCellLayout.isCompact(constraints.maxWidth);
        final carousel = DateCellLayout.useWeekCarousel(constraints.maxWidth);
        final carouselInnerWidth = constraints.maxWidth;
        final columnWidth = carousel
            ? DateCellLayout.weekCarouselColumnWidth(carouselInnerWidth)
            : null;

        final weekEventCount = weekDates.fold<int>(
          0,
          (sum, date) =>
              sum +
              filterEventsByColor(
                eventsForDay(eventsIndex, date),
                widget.colorFilter,
              ).length,
        );

        _carousel = carousel;
        _columnWidth = columnWidth ?? 0;
        if (_carousel &&
            _columnWidth > 0 &&
            _columnWidth != _lastLayoutColumnWidth) {
          _lastLayoutColumnWidth = _columnWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_needsCenterOnSelected && !_carouselBusy) {
              _scheduleCenterSelected(animate: false);
            }
            _updateTodayChipFromScroll();
          });
        }

        if (carousel) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showWeekDragHint &&
                  hasDraggableEvents &&
                  weekEventCount > 0 &&
                  widget.onWeekDragHintDismissed != null) ...[
                AlmanacHintBanner(
                  icon: Icons.open_with_rounded,
                  message: l10n.weekDragHint,
                  dismissLabel: l10n.hintDismiss,
                  onDismiss: widget.onWeekDragHintDismissed!,
                ),
                const SizedBox(height: AlmanacSpacing.xs),
              ],
              Expanded(
                child: LayoutBuilder(
                  builder: (context, eventConstraints) {
                    return _WeekCarouselPanel(
                      height: eventConstraints.maxHeight,
                      columnWidth: _columnWidth,
                      viewportWidth: carouselInnerWidth,
                      laneDates: _displayDatesForSelected(),
                      selectedDate: widget.selectedDate,
                      eventsIndex: eventsIndex,
                      activeProfileId: widget.activeProfileId,
                      colorFilter: widget.colorFilter,
                      profileSeedColors: widget.profileSeedColors,
                      profileNamesById: widget.profileNamesById,
                      onDateSelected: widget.onDateSelected,
                      onDateLongPress: widget.onDateLongPress,
                      onEditEvent: widget.onEditEvent,
                      onEventUpdated: widget.onEventUpdated,
                      onShiftQuickAction: widget.onShiftQuickAction,
                      onEventMoved: widget.onEventMoved,
                      onEventResized: widget.onEventResized,
                      scrollController: _carouselController,
                      viewportKey: _carouselViewportKey,
                      move: _move,
                      onMoveResult: _onMoveResult,
                      onScrollNotification: _handleCarouselScrollNotification,
                      scrollLocked: _carouselScrollLocked || _weekDragActive,
                      hideEmptyWeekHours: widget.hideEmptyWeekHours,
                      weekHourPaddingBefore: widget.weekHourPaddingBefore,
                      weekHourPaddingAfter: widget.weekHourPaddingAfter,
                      weekHourZoomLevel: widget.weekHourZoomLevel,
                      onWeekHourZoomLevelChanged:
                          widget.onWeekHourZoomLevelChanged,
                      forceFullHourAxis: _weekDragActive,
                      dragSession: _weekDragSession,
                      onEmptySlotTap: widget.onEmptySlotTap,
                      selectedSlot: _effectiveSlot,
                      onSelectedSlotChanged: _setSlot,
                    );
                  },
                ),
              ),
            ],
          );
        }

        final strip = CalendarWeekStrip(
          weekDates: weekDates,
          selectedDate: widget.selectedDate,
          eventsIndex: eventsIndex,
          onDateSelected: widget.onDateSelected,
          onDateLongPress: widget.onDateLongPress,
          activeProfileId: widget.activeProfileId,
          colorFilter: widget.colorFilter,
          viewportWidth: carouselInnerWidth,
          compact: isCompact,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarGridPanel(
              showWeekdayHeader: false,
              child: Row(
                children: [
                  const SizedBox(width: kWeekHourLabelWidth),
                  Expanded(child: strip),
                ],
              ),
            ),
            if (widget.showWeekDragHint &&
                hasDraggableEvents &&
                weekEventCount > 0 &&
                widget.onWeekDragHintDismissed != null) ...[
              const SizedBox(height: AlmanacSpacing.xs),
              AlmanacHintBanner(
                icon: Icons.open_with_rounded,
                message: l10n.weekDragHint,
                dismissLabel: l10n.hintDismiss,
                onDismiss: widget.onWeekDragHintDismissed!,
              ),
            ],
            const SizedBox(height: AlmanacSpacing.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, eventConstraints) {
                  return _WeekEventsPanel(
                    height: eventConstraints.maxHeight,
                    weekDates: weekDates,
                    eventsIndex: eventsIndex,
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
                    onRefresh: widget.onRefresh,
                    hideEmptyWeekHours: widget.hideEmptyWeekHours,
                    weekHourPaddingBefore: widget.weekHourPaddingBefore,
                    weekHourPaddingAfter: widget.weekHourPaddingAfter,
                    weekHourZoomLevel: widget.weekHourZoomLevel,
                    onWeekHourZoomLevelChanged:
                        widget.onWeekHourZoomLevelChanged,
                    dragSession: _weekDragSession,
                    onEmptySlotTap: widget.onEmptySlotTap,
                    selectedSlot: _effectiveSlot,
                    onSelectedSlotChanged: _setSlot,
                    gridKey: _wideGridKey,
                    move: _move,
                    onMoveResult: _onMoveResult,
                    forceFullHourAxis: _weekDragActive,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
