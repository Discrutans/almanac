import 'package:flutter/material.dart';
import '../../calendar/calendar_types.dart';
import '../../data/guest/guest_calendar_subscription.dart';

/// Read-only события из подписок на внешние .ics-календари.
abstract final class GuestCalendarProjection {
  static List<AppEvent> expandForProfiles({
    required Iterable<String> profileIds,
    required Iterable<GuestCalendarSubscription> subscriptions,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final profileSet = profileIds.toSet();
    final projected = <AppEvent>[];

    for (final subscription in subscriptions) {
      if (!profileSet.contains(subscription.profileId)) continue;
      final color = subscription.colorValue == null
          ? null
          : Color(subscription.colorValue!);

      for (final event in subscription.cachedEvents) {
        if (_overlapsRange(event, rangeStart, rangeEnd)) {
          projected.add(
            event
                .copyWith(
                  contextProfileId: subscription.profileId,
                  color: color ?? event.color,
                )
                .taggedWith(CalendarEntrySource.guestCalendar),
          );
        }
      }
    }

    projected.sort((a, b) => a.start.compareTo(b.start));
    return projected;
  }

  static bool _overlapsRange(
    AppEvent event,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    return event.end.isAfter(rangeStart) && event.start.isBefore(rangeEnd);
  }
}
