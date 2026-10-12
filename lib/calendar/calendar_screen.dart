import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/attachments/attachment_storage.dart';
import '../data/profiles/context_profile.dart';
import '../data/profiles/profile_scoped_repositories.dart';
import '../core/localization/app_localizations.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';
import '../state/calendar_filter_providers.dart';
import '../state/calendar_navigation_notifier.dart';
import '../core/ui/adaptive.dart';
import '../core/theme/almanac_motion.dart';
import '../core/ui/almanac_sheets.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_feedback.dart';
import '../notifications/event_reminder_service.dart';
import 'calendar_types.dart';
import 'calendar_entry_capabilities.dart';
import 'widgets/schedule_quick_actions_bar.dart';
import 'shift_quick_actions.dart';
import 'services/calendar_event_service.dart';
import '../data/events/recurrence_engine.dart';
import 'views/agenda_view.dart';
import 'views/month_view.dart';
import 'views/week_view.dart';
import 'views/year_view.dart';
import 'widgets/chrome/date_cell.dart';
import 'widgets/week/week_hour_axis.dart';
import 'widgets/chrome/calendar_period_swipe.dart';
import 'widgets/chrome/calendar_toolbar.dart';
import 'widgets/chrome/calendar_top_nav_bar.dart';
import 'widgets/forms/create_event_dialog.dart';
import '../core/router/app_router.dart';
import '../platform/platform_bootstrap.dart';
import '../platform/session_types.dart';
import '../booking/booking_offer.dart';
import '../booking/booking_offer_form_sheet.dart';
import '../booking/ydb_offer_booking_service.dart';
import 'services/calendar_event_lock_guard.dart';
import '../state/session_pending_providers.dart';
import '../finance/savings_goal_types.dart';
import '../finance/savings_goals_sheet.dart';
import 'event_profile_visual.dart';
import 'widgets/chrome/create_event_fab.dart';
import 'widgets/chrome/day_date_actions_sheet.dart';
import 'widgets/chrome/day_events_sheet.dart';
import 'widgets/chrome/event_preview_sheet.dart';
import 'widgets/forms/edit_event_dialog.dart';
import 'widgets/event_list_item.dart';
import 'widgets/chrome/responsive_calendar_wrapper.dart';
import 'widgets/week/week_day_column.dart';
import 'widgets/week/week_grid_slot.dart';

part 'calendar_screen_actions.dart';
part 'calendar_active_view.dart';

/// Экран календаря: навигация, загрузка событий и переключение видов.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with _CalendarScreenActions {
  @override
  void initState() {
    super.initState();
    EventReminderService.pendingEventId.addListener(_openPendingReminder);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingReminder());
  }

  @override
  void dispose() {
    EventReminderService.pendingEventId.removeListener(_openPendingReminder);
    super.dispose();
  }

  void _openPendingReminder() {
    final id = EventReminderService.pendingEventId.value;
    if (id == null || !mounted) return;
    EventReminderService.pendingEventId.value = null;
    unawaited(_openEventById(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nav = ref.watch(calendarNavigationProvider);
    final navNotifier = ref.read(calendarNavigationProvider.notifier);
    final eventsState = ref.watch(calendarEventsProvider);
    final displayEvents = ref.watch(filteredCalendarEventsProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);
    final visibleProfileIds = ref.watch(visibleProfileIdsProvider);
    final profilesState = ref.watch(contextProfilesProvider);
    final colorFilter = ref.watch(eventColorFilterProvider);
    final profileNamesById = profilesState.isSplitView
        ? {for (final p in profilesState.profiles) p.id: p.name}
        : const <String, String>{};
    final profileSeedColors = profilesState.isSplitView
        ? {for (final p in profilesState.profiles) p.id: p.seedColor}
        : const <String, Color>{};
    final visibleSchedules = _visibleSchedules();
    final store = ref.watch(localDataStoreProvider);
    final showSwipeHint = !store.swipeActionsHintSeen;
    final showWeekDragHint = !store.weekDragHintSeen;
    final weekHourZoomLevel = ref.watch(weekHourZoomLevelProvider);
    ref.watch(eventLocksRevisionProvider);
    final lockedByOtherEventIds = {
      for (final lock in ref.read(eventLockServiceProvider).cachedActive)
        if (ref.read(eventLockServiceProvider).isLockedByOther(lock.eventId))
          lock.eventId,
    };

    final access = ref.watch(activeProfileAccessProvider);
    final createBarLabel = _createBarLabel(context, l10n, nav.mode, access);
    return Scaffold(
      body: AlmanacLoadingOverlay(
        visible: _isBusy,
        message: l10n.loading,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AlmanacDecor.scaffoldGradient(
              Theme.of(context).colorScheme,
            ),
          ),
          child: ResponsiveCalendarWrapper(
            child: SafeArea(
              child: Column(
                children: [
                  CalendarTopNavBar(
                    title: nav.headerTitle(l10n),
                    navDirection: nav.navDirection,
                    onPrevious: navNotifier.previousPeriod,
                    onNext: navNotifier.nextPeriod,
                  ),
                  AlmanacGap.sm,
                  CalendarToolbar(
                    mode: nav.mode,
                    onModeChanged: navNotifier.setMode,
                    events: eventsState.events,
                  ),
                  AlmanacGap.md,
                  Expanded(
                    child: CalendarPeriodSwipeDetector(
                      onPrevious: navNotifier.previousPeriod,
                      onNext: navNotifier.nextPeriod,
                      enabled:
                          !eventsState.hasError &&
                          !(nav.mode == CalendarMode.week &&
                              DateCellLayout.useWeekCarousel(
                                context.almanacWidth,
                              )),
                      child: eventsState.hasError
                          ? AlmanacErrorPanel(
                              message: l10n.loadCalendarError,
                              retryLabel: l10n.retry,
                              onRetry: _refreshEvents,
                            )
                          : AnimatedSwitcher(
                              duration: AlmanacDurations.smooth,
                              switchInCurve: AlmanacCurves.enter,
                              switchOutCurve: AlmanacCurves.exit,
                              layoutBuilder: (currentChild, _) {
                                return currentChild ?? const SizedBox.shrink();
                              },
                              transitionBuilder: (child, animation) {
                                return almanacCalendarViewTransition(
                                  child,
                                  animation,
                                  direction: nav.navDirection,
                                );
                              },
                              child: _CalendarActiveView(
                                key: ValueKey(
                                  _calendarActiveViewKey(
                                    nav: nav,
                                    activeProfileId: activeProfileId,
                                    visibleProfileIds: visibleProfileIds,
                                  ),
                                ),
                                mode: nav.mode,
                                focusedMonth: nav.focusedMonth,
                                selectedDate: nav.selectedDate,
                                events: displayEvents,
                                activeProfileId: activeProfileId,
                                schedules: visibleSchedules,
                                colorFilter: colorFilter,
                                profileNamesById: profileNamesById,
                                profileSeedColors: profileSeedColors,
                                onDateSelected: _onDateSelected,
                                onSelectedDateInWeekChanged:
                                    navNotifier.selectDate,
                                onDateLongPress: _onDateLongPress,
                                onMonthSelected: navNotifier.selectMonth,
                                onEditEvent: _viewEvent,
                                onViewEvent: _viewEvent,
                                onDeleteEvent: _deleteEvent,
                                onCreateEvent: _createEvent,
                                onEventUpdated: _updateEvent,
                                onShiftQuickAction: access.canManageSchedules
                                    ? _applyShiftQuickAction
                                    : null,
                                onWeekEventMoved: access.canEditEvents
                                    ? _moveWeekEvent
                                    : null,
                                onWeekEventResized: access.canEditEvents
                                    ? _resizeWeekEvent
                                    : null,
                                onMoveEventToDate: access.canEditEvents
                                    ? _moveWeekEvent
                                    : null,
                                onRefresh: () async => _refreshEvents(),
                                showSwipeHint: showSwipeHint,
                                onSwipeHintDismissed: _dismissSwipeHint,
                                showWeekDragHint: showWeekDragHint,
                                onWeekDragHintDismissed: _dismissWeekDragHint,
                                scrollToTodayNonce: nav.scrollToTodayNonce,
                                weekHourZoomLevel: weekHourZoomLevel,
                                onWeekHourZoomLevelChanged: (level) {
                                  ref
                                      .read(weekHourZoomLevelProvider.notifier)
                                      .setValue(level);
                                },
                                lockedByOtherEventIds: lockedByOtherEventIds,
                                selectedSlot: _weekSelectedSlot,
                                onSelectedSlotChanged: (slot) {
                                  setState(() => _weekSelectedSlot = slot);
                                },
                              ),
                            ),
                    ),
                  ),
                  CalendarCreateBar(
                      onPressed: () {
                        final slot = _weekSelectedSlot;
                        final date =
                            nav.mode == CalendarMode.month ||
                                nav.mode == CalendarMode.year
                            ? nav.selectedDate
                            : slot?.date;
                        unawaited(
                          _createEvent(
                            date,
                            slot?.startTime,
                            slot?.endTime,
                          ),
                        );
                      },
                      label: createBarLabel,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
