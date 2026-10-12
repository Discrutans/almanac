import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/localization/app_localizations.dart';
import '../booking/booking_offer.dart';
import '../booking/booking_types.dart';
import '../data/events/calendar_entry_expander.dart';
import '../calendar/calendar_event_index.dart';
import '../calendar/calendar_types.dart';
import '../notifications/event_reminder_service.dart';
import '../booking/booking_slot_calendar_projection.dart';
import '../booking/pending_booking_calendar_projection.dart';
import '../calendar/guest_calendar_projection.dart';
import '../platform/today_home_widget_service.dart';
import 'app_providers.dart';
import 'calendar_filter_providers.dart';
import 'session_pending_providers.dart';
import 'calendar_navigation_notifier.dart';

/// Состояние загрузки событий для текущего периода календаря.
class CalendarEventsState {
  const CalendarEventsState({required this.events, this.hasError = false});

  /// События, попадающие в [CalendarNavigationState.visibleRange].
  final List<AppEvent> events;

  /// Ошибка при чтении репозитория.
  final bool hasError;

  static const empty = CalendarEventsState(events: []);
}

/// Загружает события видимых профилей для активного диапазона навигации.
class CalendarEventsNotifier extends Notifier<CalendarEventsState> {
  String? _reminderSyncKey;

  @override
  CalendarEventsState build() {
    ref.watch(calendarNavigationProvider);
    final profileIds = ref.watch(visibleProfileIdsProvider);
    ref.watch(activeProfileIdProvider);
    final schedulesVersion = ref.watch(schedulesVersionProvider);
    final savingsGoalsVersion = ref.watch(savingsGoalsVersionProvider);
    ref.watch(pendingBookingsProvider);
    ref.watch(remoteSessionPendingListProvider);
    ref.watch(openBookingSessionsProvider);
    ref.watch(activeProfileAccessProvider);
    final locale = ref.watch(appLocaleProvider);
    final settingsRevision = ref.watch(platformSettingsRevisionProvider);

    final syncKey =
        '${profileIds.join(',')}|$schedulesVersion|$savingsGoalsVersion|$locale|$settingsRevision';
    final shouldSyncReminders = _reminderSyncKey != syncKey;
    if (shouldSyncReminders) {
      _reminderSyncKey = syncKey;
    }

    final result = _loadEvents();
    if (shouldSyncReminders) {
      _syncReminders();
    }
    return result;
  }

  /// Перечитывает события (после создания, редактирования, удаления).
  void reload() {
    state = _loadEvents();
    _syncReminders();
  }

  CalendarEventsState _loadEvents() {
    try {
      final range = ref.read(calendarNavigationProvider).visibleRange();
      final profileIds = ref.read(visibleProfileIdsProvider);
      final merged = CalendarEntryExpander.expandVisibleProfiles(
        eventRepository: ref.read(eventRepositoryProvider),
        savingsGoalRepository: ref.read(savingsGoalRepositoryProvider),
        profileIds: profileIds,
        rangeStart: range.start,
        rangeEnd: range.end,
      );

      final bookingRepo = ref.read(bookingRepositoryProvider);
      final localPending = <BookingRequest>[];
      for (final profileId in profileIds) {
        localPending.addAll(
          bookingRepo.getPendingRequests(profileId: profileId),
        );
      }

      merged.addAll(
        PendingBookingCalendarProjection.expandForProfiles(
          localPending: localPending,
          remotePending: ref.read(activeProfileAccessProvider).canBookOnly
              ? const []
              : ref.read(remoteSessionPendingListProvider),
          rangeStart: range.start,
          rangeEnd: range.end,
        ),
      );

      if (ref.read(activeProfileAccessProvider).canBookOnly) {
        merged.addAll(
          BookingSlotCalendarProjection.expand(
            sessions:
                ref.read(openBookingSessionsProvider).valueOrNull ?? const [],
            rangeStart: range.start,
            rangeEnd: range.end,
            profileId: ref.read(activeProfileIdProvider),
          ),
        );
      }

      if (!ref.read(activeProfileAccessProvider).canBookOnly) {
        merged.addAll(
          GuestCalendarProjection.expandForProfiles(
            profileIds: profileIds,
            subscriptions: ref.read(localDataStoreProvider).allGuestCalendars(),
            rangeStart: range.start,
            rangeEnd: range.end,
          ),
        );
      }

      merged.sort((a, b) => a.start.compareTo(b.start));

      final access = ref.read(activeProfileAccessProvider);
      if (access.canBookOnly) {
        final l10n = AppLocalizations.forLocale(ref.read(appLocaleProvider));
        final active = ref.read(contextProfilesProvider).active;
        final visible = BookingOfferEvents.surfaceForGuest(
          events: merged,
          guestProfileId: active.id,
          occupiedTitle: l10n.bookingOccupied,
          guestName: active.name,
        );
        merged
          ..clear()
          ..addAll(visible);
      }

      final snapshot = List<AppEvent>.unmodifiable(merged);
      unawaited(
        Future.microtask(
          () => TodayHomeWidgetService.updateTodayEvents(snapshot),
        ),
      );

      return CalendarEventsState(events: merged);
    } catch (error, stackTrace) {
      debugPrint('CalendarEventsNotifier: $error\n$stackTrace');
      return const CalendarEventsState(events: [], hasError: true);
    }
  }

  void _syncReminders() {
    Future.microtask(() {
      try {
        final configs = ref.read(platformConfigRepositoryProvider);
        EventReminderService.instance.syncUpcomingFromRepository(
          eventRepository: ref.read(eventRepositoryProvider),
          profileIds: ref
              .read(contextProfileRepositoryProvider)
              .getAll()
              .map((profile) => profile.id)
              .where(
                (id) => configs
                    .getOrCreateConfig(profileId: id)
                    .notificationsEnabled,
              ),
          locale: ref.read(appLocaleProvider),
        );
      } catch (_) {
        // Provider may be disposed after profile switch.
      }
    });
  }
}

final calendarEventsProvider =
    NotifierProvider<CalendarEventsNotifier, CalendarEventsState>(
      CalendarEventsNotifier.new,
    );

/// События календаря с учётом цветового фильтра.
final filteredCalendarEventsProvider = Provider<List<AppEvent>>((ref) {
  final events = ref.watch(calendarEventsProvider).events;
  final colorFilter = ref.watch(eventColorFilterProvider);
  return filterEventsByColor(events, colorFilter);
});

/// Индекс по дням — один обход списка на загрузку, общий для панелей.
final calendarEventsByDayProvider = Provider<Map<DateTime, List<AppEvent>>>((
  ref,
) {
  return indexEventsByDay(ref.watch(calendarEventsProvider).events);
});

/// Заметки и чек-листы без даты для Inbox.
final undatedInboxEventsProvider = Provider<List<AppEvent>>((ref) {
  ref.watch(calendarEventsProvider);
  final profileIds = ref.watch(visibleProfileIdsProvider);
  final repo = ref.watch(eventRepositoryProvider);
  final merged = <AppEvent>[];
  for (final profileId in profileIds) {
    merged.addAll(
      repo
          .getUndatedEvents(profileId: profileId)
          .map((event) => event.copyWith(contextProfileId: profileId)),
    );
  }
  return merged;
});
