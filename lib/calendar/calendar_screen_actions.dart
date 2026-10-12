part of 'calendar_screen.dart';

mixin _CalendarScreenActions on ConsumerState<CalendarScreen> {
  bool _isBusy = false;
  WeekGridSlot? _weekSelectedSlot;

  CalendarEventService _eventService() {
    return CalendarEventService(
      eventRepository: ref.read(eventRepositoryProvider),
      combinedRepository: ref.read(combinedEventRepositoryProvider),
      activeProfileId: ref.read(activeProfileIdProvider),
    );
  }

  CalendarEventLockGuard _lockGuard() {
    return CalendarEventLockGuard(
      locks: ref.read(eventLockServiceProvider),
      onChanged: () => ref.read(eventLocksRevisionProvider.notifier).state++,
    );
  }

  YdbOfferBookingService _ydbBooking() {
    return YdbOfferBookingService(
      events: _eventService(),
      lockGuard: _lockGuard(),
      sync: ref.read(remoteSyncServiceProvider),
      autoSync: ref.read(remoteAutoSyncSchedulerProvider),
    );
  }

  ProfileAccess _accessForEvent(AppEvent event) {
    final state = ref.read(contextProfilesProvider);
    final profileId = event.contextProfileId;
    if (profileId != null) {
      for (final profile in state.profiles) {
        if (profile.id == profileId) return profile.access;
      }
    }
    return state.active.access;
  }

  Future<bool> _isLockedByOther(AppEvent event) {
    return _lockGuard().isLockedByOther(
      event: event,
      needsLocks: _accessForEvent(event).needsEventLocks,
    );
  }

  Future<bool> _blockIfLocked(AppEvent event) async {
    if (!await _isLockedByOther(event)) return false;
    if (mounted) {
      AlmanacFeedback.showError(
        context,
        AppLocalizations.of(context).eventLockedByOther,
      );
    }
    return true;
  }

  void _refreshEvents() {
    ref.read(calendarEventsProvider.notifier).reload();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  List<CyclicWorkSchedule> _visibleSchedules() {
    final scheduleRepo = ref.read(cyclicWorkScheduleRepositoryProvider);
    final visible = ref.read(visibleProfileIdsProvider);
    final result = <CyclicWorkSchedule>[];
    for (final profileId in visible) {
      result.addAll(scheduleRepo.getForProfile(profileId));
    }
    return result;
  }

  void _dismissSwipeHint() {
    ref.read(localDataStoreProvider).markSwipeActionsHintSeen();
    setState(() {});
  }

  void _dismissWeekDragHint() {
    ref.read(localDataStoreProvider).markWeekDragHintSeen();
    setState(() {});
  }

  void _showDayDateActions(DateTime date) {
    final access = ref.read(activeProfileAccessProvider);
    unawaited(
      DayDateActionsSheet.show(
        context: context,
        date: date,
        canCreate: access.canCreateEvents ||
            access.canJoinBooking ||
            access.canBookOnly,
        onCreate: () {
          ref.read(calendarNavigationProvider.notifier).selectDate(date);
          unawaited(_createEvent(date));
        },
        onViewDay: () {
          ref.read(calendarNavigationProvider.notifier).selectDate(date);
          _showDaySheet(date);
        },
      ),
    );
  }

  void _onDateLongPress(DateTime date) {
    final nav = ref.read(calendarNavigationProvider);
    if (nav.mode == CalendarMode.month) {
      ref.read(calendarNavigationProvider.notifier).openWeekView(date);
      return;
    }
    _showDayDateActions(date);
  }

  void _onDateSelected(DateTime date) {
    final nav = ref.read(calendarNavigationProvider);
    final navNotifier = ref.read(calendarNavigationProvider.notifier);
    if (nav.mode == CalendarMode.month) {
      navNotifier.selectDate(date);
      _showDaySheet(date);
      return;
    }
    if (nav.mode == CalendarMode.week) {
      navNotifier.selectDate(date);
      if (_weekSelectedSlot != null && !_weekSelectedSlot!.isOnDate(date)) {
        setState(() => _weekSelectedSlot = null);
      }
      return;
    }
    navNotifier.selectDate(date);
  }

  void _showDaySheet(DateTime date) {
    final activeProfileId = ref.read(activeProfileIdProvider);
    final access = ref.read(activeProfileAccessProvider);
    final l10n = AppLocalizations.of(context);

    unawaited(
      DayEventsSheet.show(
        context: context,
        date: date,
        activeProfileId: activeProfileId,
        onViewEvent: _viewEvent,
        onEditEvent: _viewEvent,
        onDeleteEvent: _deleteEvent,
        onCreateEvent: () => unawaited(_createEvent(date)),
        createLabel: access.canBookOnly ? l10n.bookAppointmentAction : null,
        onEventUpdated: _updateEvent,
        onShiftQuickAction: access.canManageSchedules
            ? _applyShiftQuickAction
            : null,
        showSwipeHint: !ref.read(localDataStoreProvider).swipeActionsHintSeen,
        onSwipeHintDismissed: _dismissSwipeHint,
        onOpenWeekView: () {
          ref.read(calendarNavigationProvider.notifier).openWeekView(date);
        },
      ),
    );
  }

  Future<void> _editEventInPreview(AppEvent event) async {
    if (event.entrySource == CalendarEntrySource.bookingSlot) {
      await _viewEvent(event);
      return;
    }
    if (await _isLockedByOther(event)) {
      if (mounted) {
        AlmanacFeedback.showError(
          context,
          AppLocalizations.of(context).eventLockedByOther,
        );
      }
      await _viewEvent(event);
      return;
    }
    await _viewEvent(event, startInEdit: true);
  }

  Future<void> _openEventById(String eventId) async {
    final visible = ref.read(visibleProfileIdsProvider);
    final repo = ref.read(eventRepositoryProvider);
    AppEvent? found;
    for (final profileId in visible) {
      for (final event in repo.getMasterEvents(profileId: profileId)) {
        if (event.id == eventId) {
          found = event.copyWith(contextProfileId: profileId);
          break;
        }
      }
      if (found != null) break;
    }
    if (found == null) {
      for (final event in ref.read(calendarEventsProvider).events) {
        if (event.id == eventId) {
          found = event;
          break;
        }
      }
    }
    if (found == null || !mounted) return;
    await _viewEvent(found);
  }

  Future<void> _viewEvent(AppEvent event, {bool startInEdit = false}) async {
    if (!mounted) return;
    if (event.entrySource == CalendarEntrySource.bookingSlot) {
      _openBookingSlotEvent(event);
      return;
    }
    final activeProfileId = ref.read(activeProfileIdProvider);
    final access = _accessForEvent(event);
    final activeAccess = ref.read(activeProfileAccessProvider);
    final l10n = AppLocalizations.of(context);
    final profilesState = ref.read(contextProfilesProvider);
    final profileId = event.contextProfileId;
    String? profileLabel;
    Color? profileSeedColor;
    if (profileId != null &&
        isForeignProfileEvent(event, activeProfileId) &&
        profilesState.isSplitView) {
      for (final profile in profilesState.profiles) {
        if (profile.id == profileId) {
          profileLabel = profile.name;
          profileSeedColor = profile.seedColor;
          break;
        }
      }
    }

    final needsLock = access.needsEventLocks;
    final locks = ref.read(eventLockServiceProvider);
    final guard = _lockGuard();
    if (needsLock) {
      await locks.refreshActive();
      if (!mounted) return;
      ref.read(eventLocksRevisionProvider.notifier).state++;
    }
    if (!mounted) return;
    final lockedByOther = needsLock && locks.isLockedByOther(event.id);
    final ownBooking = BookingOfferEvents.isBookedBy(
      event,
      profileId: activeProfileId,
      guestName: profilesState.active.name,
    );
    String? actionLabel;
    Future<void> Function()? onAction;
    if (activeAccess.canBookOnly &&
        event.entrySource == CalendarEntrySource.bookingOffer) {
      actionLabel = l10n.bookThisSlot;
      onAction = () async {
        await _bookYdbOffer(event, alreadyConfirmed: true);
        if (mounted) Navigator.of(context).pop();
      };
    } else if (activeAccess.canCancelOwnBooking && ownBooking) {
      actionLabel = l10n.cancelBooking;
      onAction = () async {
        final cancelled = await _cancelOwnBooking(event);
        if (cancelled && mounted) Navigator.of(context).pop();
      };
    }

    await EventPreviewSheet.show(
      context: context,
      event: event,
      activeProfileId: activeProfileId,
      profileLabel: profileLabel,
      profileSeedColor: profileSeedColor,
      onEventUpdated: access.canEditEvents ? _updateEvent : null,
      onEditSavings: event.isSavingsGoal ? () => _editEvent(event) : null,
      onDuplicate: access.canEditEvents && !event.isSavingsGoal
          ? _duplicateEvent
          : null,
      existingEvents: event.isSavingsGoal
          ? const []
          : _eventService().conflictMasters(),
      allowDelete:
          event.capabilities.showDeleteInEditor &&
          access.canDeleteEvents &&
          !lockedByOther,
      allowRevertOverride:
          event.capabilities.canRevertOverride && access.canEditEvents,
      allowEdit: access.canEditEvents && !lockedByOther,
      onSave: event.isSavingsGoal || !access.canEditEvents || lockedByOther
          ? null
          : _persistEditedEvent(event),
      onDelete: event.isSavingsGoal || lockedByOther
          ? null
          : _deleteEditedEvent(event),
      onRevertOverride: event.isSavingsGoal ? null : _revertEditedEvent(event),
      startInEdit: startInEdit && access.canEditEvents && !lockedByOther,
      acquireEditLock: needsLock
          ? () async {
              final result = await guard.acquire(event.id);
              return result.acquired;
            }
          : null,
      releaseEditLock: needsLock ? () => guard.release(event.id) : null,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  Future<void> _duplicateEvent(AppEvent source) async {
    final day = source.start.toLocal();
    final date = DateTime(day.year, day.month, day.day);
    await _createEntryForDate(
      date,
      kind: source.kind,
      duplicateFrom: source,
    );
  }

  EditEventSaveCallback _persistEditedEvent(AppEvent original) {
    return (
      updated, {
      recurrenceScope = RecurrenceEditScope.wholeSeries,
    }) async {
      final service = _eventService();
      final l10n = AppLocalizations.of(context);
      try {
        service.persistEditedEvent(
          original: original,
          updated: updated,
          recurrenceScope: recurrenceScope,
        );
        if (mounted) _refreshEvents();
      } catch (error) {
        if (mounted) {
          AlmanacFeedback.showError(context, l10n.eventSaveFailed(error));
        }
        rethrow;
      }
    };
  }

  Future<void> Function(AppEvent)? _deleteEditedEvent(AppEvent event) {
    if (!event.capabilities.showDeleteInEditor) return null;
    return (target) async {
      final l10n = AppLocalizations.of(context);
      try {
        await _performDelete(target);
      } catch (error) {
        if (mounted) {
          AlmanacFeedback.showError(context, l10n.eventDeleteFailed(error));
        }
        rethrow;
      }
    };
  }

  Future<void> Function(AppEvent)? _revertEditedEvent(AppEvent event) {
    if (!event.capabilities.canRevertOverride) return null;
    return (target) async {
      final l10n = AppLocalizations.of(context);
      try {
        _eventService().revertScheduleOverride(target);
        if (mounted) _refreshEvents();
      } catch (error) {
        if (mounted) {
          AlmanacFeedback.showError(context, l10n.eventDeleteFailed(error));
        }
        rethrow;
      }
    };
  }

  Future<void> _editEvent(AppEvent event) async {
    if (!_accessForEvent(event).canEditEvents) {
      await _viewEvent(event);
      return;
    }
    if (event.isSavingsGoal) {
      final goal = _findSavingsGoal(event);
      if (goal == null || !mounted) return;
      await SavingsGoalsSheet.openGoalForm(context, ref, existing: goal);
      if (mounted) _refreshEvents();
      return;
    }

    final service = _eventService();
    final caps = event.capabilities;
    final needsLock = _accessForEvent(event).needsEventLocks;
    final guard = _lockGuard();
    if (needsLock) {
      final result = await guard.acquire(event.id);
      if (!result.acquired) {
        if (!mounted) return;
        AlmanacFeedback.showError(
          context,
          AppLocalizations.of(context).eventLockedByOther,
        );
        await _viewEvent(event);
        return;
      }
    }

    if (!mounted) {
      if (needsLock) await guard.release(event.id);
      return;
    }

    try {
      await EditEventDialog.show(
        context: context,
        event: event,
        existingEvents: service.conflictMasters(),
        allowDelete: caps.showDeleteInEditor,
        allowRevertOverride: caps.canRevertOverride,
        onSave: _persistEditedEvent(event),
        onRevertOverride: _revertEditedEvent(event),
        onDelete: _deleteEditedEvent(event),
      );
    } finally {
      if (needsLock) {
        await guard.release(event.id);
      }
    }
  }

  void _moveWeekEvent(
    AppEvent event,
    DateTime targetDate, [
    TimeOfDay? startTime,
  ]) {
    if (!_accessForEvent(event).canEditEvents) return;
    if (event.isSavingsGoal) {
      _moveSavingsGoal(event, targetDate);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final nav = ref.read(calendarNavigationProvider);
    final navNotifier = ref.read(calendarNavigationProvider.notifier);
    final currentWeekStart = CalendarNavigationState.weekStartMonday(
      nav.selectedDate,
    );
    final targetWeekStart = CalendarNavigationState.weekStartMonday(targetDate);

    unawaited(
      _runBusy(() async {
        if (await _blockIfLocked(event)) return;
        try {
          _eventService().movePersonalEventToDateTime(
            event: event,
            targetDate: targetDate,
            startTime: startTime,
          );
          if (targetWeekStart != currentWeekStart) {
            navNotifier.selectDate(targetDate);
          }
          if (mounted) {
            _refreshEvents();
            AlmanacFeedback.showSuccess(context, l10n.eventTimeUpdated);
          }
        } catch (error) {
          if (!mounted) return;
          AlmanacFeedback.showError(context, l10n.eventSaveFailed(error));
        }
      }),
    );
  }

  void _resizeWeekEvent(AppEvent event, int startMinutes, int endMinutes) {
    if (!_accessForEvent(event).canEditEvents) return;
    if (!event.isTimed || !event.capabilities.canMoveOnWeekGrid) return;

    final l10n = AppLocalizations.of(context);
    unawaited(
      _runBusy(() async {
        if (await _blockIfLocked(event)) return;
        try {
          _eventService().resizePersonalEvent(
            event: event,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
          );
          if (mounted) _refreshEvents();
        } catch (error) {
          if (!mounted) return;
          AlmanacFeedback.showError(context, l10n.eventSaveFailed(error));
        }
      }),
    );
  }

  SavingsGoal? _findSavingsGoal(AppEvent event) {
    final profileId =
        event.contextProfileId ?? ref.read(contextProfilesProvider).active.id;
    final goals = ref
        .read(savingsGoalRepositoryProvider)
        .getForProfile(profileId);
    for (final goal in goals) {
      if (goal.id == event.id) return goal;
    }
    return null;
  }

  void _moveSavingsGoal(AppEvent event, DateTime targetDate) {
    final goal = _findSavingsGoal(event);
    if (goal == null) return;

    final day = DateTime(targetDate.year, targetDate.month, targetDate.day);
    if (event.isOnDate(day)) return;

    final nav = ref.read(calendarNavigationProvider);
    final navNotifier = ref.read(calendarNavigationProvider.notifier);
    final currentWeekStart = CalendarNavigationState.weekStartMonday(
      nav.selectedDate,
    );
    final targetWeekStart = CalendarNavigationState.weekStartMonday(targetDate);

    unawaited(
      _runBusy(() async {
        ref
            .read(savingsGoalRepositoryProvider)
            .update(
              profileId: goal.profileId,
              goal: goal.copyWith(targetDate: day),
            );
        ref.read(savingsGoalsVersionProvider.notifier).state++;
        if (targetWeekStart != currentWeekStart) {
          navNotifier.selectDate(targetDate);
        }
        if (mounted) _refreshEvents();
      }),
    );
  }

  Future<bool> _deleteSavingsGoal(AppEvent event) async {
    final goal = _findSavingsGoal(event);
    if (goal == null) return false;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.deleteSavingsGoalTitle,
      message: l10n.deleteSavingsGoalConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: l10n.deleteEvent,
      destructive: true,
    );

    if (confirmed != true) return false;

    ref
        .read(savingsGoalRepositoryProvider)
        .delete(profileId: goal.profileId, goalId: goal.id);
    ref.read(savingsGoalsVersionProvider.notifier).state++;
    if (mounted) _refreshEvents();
    return true;
  }

  Future<bool> _deleteEvent(AppEvent event) async {
    if (event.isSavingsGoal) {
      return _deleteSavingsGoal(event);
    }
    if (!_accessForEvent(event).canDeleteEvents) return false;
    if (await _blockIfLocked(event)) return false;
    if (!mounted) return false;

    final l10n = AppLocalizations.of(context);
    final caps = event.capabilities;

    if (!caps.canDelete) {
      if (!mounted) return false;
      AlmanacFeedback.showError(
        context,
        caps.canRevertOverride
            ? l10n.scheduleOverrideDeleteHint
            : l10n.scheduleEventDeleteHint,
      );
      return false;
    }
    final releaseSlot =
        event.entrySource == CalendarEntrySource.booking &&
        _accessForEvent(event).canReleaseBooking;
    final closeOffer = event.entrySource == CalendarEntrySource.bookingOffer;
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: releaseSlot
          ? l10n.releaseBookingTitle
          : closeOffer
          ? l10n.closeBookingSlotTitle
          : l10n.deleteEvent,
      message: releaseSlot
          ? l10n.releaseBookingConfirm
          : closeOffer
          ? l10n.closeBookingSlotConfirm
          : l10n.deleteEventConfirm,
      cancelLabel: l10n.cancel,
      confirmLabel: releaseSlot
          ? l10n.releaseBookingTitle
          : closeOffer
          ? l10n.closeBookingSlotTitle
          : l10n.deleteEvent,
      destructive: true,
    );

    if (confirmed != true) return false;

    await _performDelete(event);
    return true;
  }

  Future<void> _performDelete(AppEvent event) async {
    final l10n = AppLocalizations.of(context);
    await _runBusy(() async {
      await AlmanacFeedback.runGuarded(context, () async {
        if (event.entrySource == CalendarEntrySource.booking &&
            _accessForEvent(event).canReleaseBooking) {
          _eventService().updatePersonalEvent(
            source: event,
            updated: BookingOfferEvents.released(event),
          );
        } else {
          _eventService().deletePersonalEvent(event);
          await AttachmentStorage.deleteEventAttachments(event.id);
        }
        if (mounted) _refreshEvents();
      }, errorPrefix: l10n.eventDeleteError);
    });
  }

  Future<void> _updateEvent(AppEvent updated) async {
    if (!_accessForEvent(updated).canEditEvents) return;
    if (await _blockIfLocked(updated)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await _runBusy(() async {
      await AlmanacFeedback.runGuarded(context, () async {
        final service = _eventService();
        if (updated.capabilities.editsCreateScheduleOverride) {
          service.saveScheduleOverride(source: updated, updated: updated);
        } else {
          service.updatePersonalEvent(source: updated, updated: updated);
        }
        if (mounted) _refreshEvents();
      }, errorPrefix: l10n.eventUpdateError);
    });
  }

  Future<void> _applyShiftQuickAction(
    AppEvent event,
    ShiftQuickAction action,
  ) async {
    if (!_accessForEvent(event).canManageSchedules) return;
    final l10n = AppLocalizations.of(context);
    await _runBusy(() async {
      await AlmanacFeedback.runGuarded(context, () async {
        _eventService().applyShiftQuickAction(source: event, action: action);
        if (mounted) _refreshEvents();
      }, errorPrefix: l10n.eventUpdateError);
    });
  }

  void _openBookingSlotEvent(AppEvent event) {
    final parsed = AppEvent.parseBookingSlotEventId(event.id);
    if (parsed == null) return;
    _openBookingSession(parsed.token, slotId: parsed.slotId);
  }

  void _openBookingSession(String token, {String? slotId}) {
    final path = slotId == null || slotId.isEmpty
        ? '/session/$token'
        : '/session/$token?slot=${Uri.encodeQueryComponent(slotId)}';
    unawaited(ref.read(appRouterProvider).push(path));
  }

  String? _firstFreeSlotOnDate(PlatformSession session, DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final slot in session.state.slots) {
      final start = slot.start.toLocal();
      if (start.year != day.year ||
          start.month != day.month ||
          start.day != day.day) {
        continue;
      }
      if (!session.isSlotFull(slot.id)) return slot.id;
    }
    return null;
  }

  Future<void> _bookYdbOffer(
    AppEvent offer, {
    bool alreadyConfirmed = false,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final state = BookingOfferEvents.readState(offer);
    if (state.isFull) {
      AlmanacFeedback.showError(context, l10n.bookingOfferTaken);
      return;
    }
    if (await _blockIfLocked(offer)) return;
    if (!mounted) return;

    if (!alreadyConfirmed) {
      final confirmed = await showAlmanacConfirm(
        context: context,
        title: l10n.bookThisSlot,
        message: l10n.bookingOfferConfirm(BookingOfferEvents.timeLabel(offer)),
        confirmLabel: l10n.bookAppointmentAction,
        cancelLabel: l10n.cancel,
      );
      if (!mounted || confirmed != true) return;
    }

    final guest = ref.read(contextProfilesProvider).active;
    if (state.isBookedBy(guest.id, guestName: guest.name)) {
      AlmanacFeedback.showSuccess(context, l10n.bookingOfferBooked);
      return;
    }

    Map<String, String> fields = const {};
    if (state.formFields.isNotEmpty) {
      final filled = await BookingOfferFormSheet.show(
        context: context,
        fields: state.formFields,
        guestName: guest.name,
      );
      if (!mounted || filled == null) return;
      fields = filled;
    }

    final String profileId =
        offer.contextProfileId ?? ref.read(activeProfileIdProvider);
    final status = await _ydbBooking().book(
      offer: offer,
      guestProfileId: guest.id,
      guestName: YdbOfferBookingService.displayName(
        fields: fields,
        fallback: guest.name,
      ),
      fields: fields,
      workspaceProfileId: profileId,
      onEventsChanged: _refreshEvents,
    );
    if (!mounted) return;
    switch (status) {
      case YdbOfferBookStatus.booked:
        AlmanacFeedback.showSuccess(context, l10n.bookingOfferBooked);
      case YdbOfferBookStatus.alreadyBooked:
        AlmanacFeedback.showSuccess(context, l10n.bookingOfferBooked);
      case YdbOfferBookStatus.taken:
      case YdbOfferBookStatus.missing:
        AlmanacFeedback.showError(context, l10n.bookingOfferTaken);
      case YdbOfferBookStatus.locked:
        AlmanacFeedback.showError(context, l10n.eventLockedByOther);
    }
  }

  Future<bool> _cancelOwnBooking(AppEvent event) async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAlmanacConfirm(
      context: context,
      title: l10n.cancelBooking,
      message: l10n.cancelBookingConfirm,
      confirmLabel: l10n.cancelBooking,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!mounted || confirmed != true) return false;
    if (await _blockIfLocked(event)) return false;

    final String profileId =
        event.contextProfileId ?? ref.read(activeProfileIdProvider);
    final status = await _ydbBooking().cancelOwn(
      event: event,
      guestProfileId: ref.read(activeProfileIdProvider),
      workspaceProfileId: profileId,
      onEventsChanged: _refreshEvents,
    );
    if (!mounted) return false;
    switch (status) {
      case YdbOfferCancelStatus.cancelled:
        AlmanacFeedback.showSuccess(context, l10n.bookingCancelled);
        return true;
      case YdbOfferCancelStatus.locked:
        AlmanacFeedback.showError(context, l10n.eventLockedByOther);
        return false;
    }
  }

  List<AppEvent> _ydbOffersOnDate(DateTime date) {
    return ref
        .read(calendarEventsProvider)
        .events
        .where(
          (event) =>
              event.entrySource == CalendarEntrySource.bookingOffer &&
              BookingOfferEvents.isOnDate(event, date),
        )
        .toList();
  }

  Future<void> _bookExistingSession({DateTime? forDate}) async {
    final l10n = AppLocalizations.of(context);
    final selectedDate =
        forDate ?? ref.read(calendarNavigationProvider).selectedDate;
    final offers = _ydbOffersOnDate(selectedDate);
    if (offers.isNotEmpty) {
      AppEvent? offer = offers.length == 1 ? offers.first : null;
      offer ??= await showAlmanacSheet<AppEvent>(
        context: context,
        placement: AlmanacSheetPlacement.bottom,
        title: l10n.pickBookingSession,
        size: AlmanacPanelSize.hug,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in offers)
              ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: Text(item.title),
                subtitle: Text(BookingOfferEvents.timeLabel(item)),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      );
      if (!mounted || offer == null) return;
      await _bookYdbOffer(offer);
      return;
    }

    List<PlatformSession> sessions;
    try {
      sessions = await ref.read(openBookingSessionsProvider.future);
    } catch (_) {
      if (mounted) {
        AlmanacFeedback.showError(context, l10n.bookingNoSessionsYet);
      }
      return;
    }
    if (!mounted) return;
    if (sessions.isEmpty) {
      AlmanacFeedback.showError(context, l10n.bookingNoSessionsYet);
      return;
    }

    PlatformSession? session = sessions.length == 1 ? sessions.first : null;
    session ??= await showAlmanacSheet<PlatformSession>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.pickBookingSession,
      size: AlmanacPanelSize.hug,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in sessions)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(item.title),
              onTap: () => Navigator.pop(context, item),
            ),
        ],
      ),
    );
    if (!mounted || session == null) return;
    final slotId = forDate == null
        ? null
        : _firstFreeSlotOnDate(session, forDate);
    _openBookingSession(session.token, slotId: slotId);
  }

  Future<void> _createEvent([
    DateTime? forDate,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  ]) async {
    final selectedDate =
        forDate ?? ref.read(calendarNavigationProvider).selectedDate;
    final access = ref.read(activeProfileAccessProvider);
    if (access.canBookOnly) {
      await _bookExistingSession(forDate: selectedDate);
      return;
    }
    if (!access.canCreateEvents) {
      if (mounted) {
        AlmanacFeedback.showError(
          context,
          AppLocalizations.of(context).bookingMemberCreateHint,
        );
      }
      return;
    }
    await _createEntryForDate(
      selectedDate,
      kind: CalendarEntryKind.event,
      initialStartTime: startTime,
      initialEndTime: endTime,
    );
  }

  Future<void> _createEntryForDate(
    DateTime date, {
    required CalendarEntryKind kind,
    TimeOfDay? initialStartTime,
    TimeOfDay? initialEndTime,
    bool initialUndated = false,
    AppEvent? duplicateFrom,
  }) async {
    final l10n = AppLocalizations.of(context);

    await CreateEventDialog.show(
      context: context,
      date: date,
      existingEvents: _eventService().conflictMasters(),
      initialKind: kind,
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
      initialUndated: initialUndated,
      duplicateFrom: duplicateFrom,
      onPersist: (event) async {
        try {
          final String profileId =
              event.contextProfileId ?? ref.read(activeProfileIdProvider);
          ref
              .read(contextProfilesProvider.notifier)
              .ensureProfileVisible(profileId);
          _eventService().createPersonalEvent(
            event,
            ProfileScopedEventRepository(
              ref.read(eventRepositoryProvider),
              profileId,
            ),
          );
          if (mounted) {
            setState(() => _weekSelectedSlot = null);
            _refreshEvents();
          }
        } catch (error) {
          if (mounted) {
            AlmanacFeedback.showError(context, l10n.eventCreateFailed(error));
          }
          rethrow;
        }
      },
    );
  }

  String? _createBarLabel(
    BuildContext context,
    AppLocalizations l10n,
    CalendarMode mode,
    ProfileAccess access,
  ) {
    if (access.canBookOnly) {
      return l10n.bookAppointmentAction;
    }
    if (mode == CalendarMode.week && _weekSelectedSlot != null) {
      final slot = _weekSelectedSlot!;
      final mat = MaterialLocalizations.of(context);
      final range =
          '${mat.formatTimeOfDay(slot.startTime)} – ${mat.formatTimeOfDay(slot.endTime)}';
      return l10n.createBarSlotLabel(range);
    }
    return null;
  }
}
