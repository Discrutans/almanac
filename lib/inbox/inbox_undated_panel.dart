import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_types.dart';
import '../calendar/event_profile_visual.dart';
import '../calendar/services/calendar_event_service.dart';
import '../calendar/widgets/chrome/event_preview_sheet.dart';
import '../calendar/widgets/event_list_item.dart';
import '../calendar/widgets/forms/create_event_dialog.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/almanac_tokens.dart';
import '../data/events/recurrence_engine.dart';
import '../data/profiles/profile_scoped_repositories.dart';
import '../state/app_providers.dart';
import '../state/calendar_events_notifier.dart';

class InboxUndatedPanel extends ConsumerWidget {
  const InboxUndatedPanel({super.key});

  CalendarEventService _service(WidgetRef ref) {
    return CalendarEventService(
      eventRepository: ref.read(eventRepositoryProvider),
      combinedRepository: ref.read(combinedEventRepositoryProvider),
      activeProfileId: ref.read(activeProfileIdProvider),
    );
  }

  String? _profileLabel(
    AppEvent event,
    String activeProfileId,
    WidgetRef ref,
  ) {
    if (!isForeignProfileEvent(event, activeProfileId)) return null;
    final id = event.contextProfileId;
    if (id == null) return null;
    for (final profile in ref.read(contextProfilesProvider).profiles) {
      if (profile.id == id) return profile.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(undatedInboxEventsProvider);
    final access = ref.watch(activeProfileAccessProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.undatedInboxSectionTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AlmanacSpacing.xs),
        if (access.canCreateEvents)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _createUndated(context, ref),
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: Text(l10n.addUndatedNote),
            ),
          ),
        if (events.isEmpty)
          Text(
            l10n.undatedInboxEmpty,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.almanacColors.muted,
            ),
          )
        else
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
              child: EventListItem(
                event: event,
                activeProfileId: activeProfileId,
                profileLabel: _profileLabel(event, activeProfileId, ref),
                compactActions: true,
                dense: true,
                onViewEvent: (item) => _open(context, ref, item),
                onEditEvent: (item) => _open(context, ref, item),
                onDeleteEvent: (item) async {
                  _service(ref).deletePersonalEvent(item);
                  ref.read(calendarEventsProvider.notifier).reload();
                  return true;
                },
                onEventUpdated: (item) {
                  _service(ref).updatePersonalEvent(
                    source: event,
                    updated: item,
                  );
                  ref.read(calendarEventsProvider.notifier).reload();
                },
                onMoveToDate: (item, date) {
                  _service(ref).movePersonalEventToDateTime(
                    event: item,
                    targetDate: date,
                  );
                  ref.read(calendarEventsProvider.notifier).reload();
                },
              ),
            ),
      ],
    );
  }

  Future<void> _createUndated(BuildContext context, WidgetRef ref) async {
    await CreateEventDialog.show(
      context: context,
      date: DateTime.now(),
      existingEvents: const [],
      initialKind: CalendarEntryKind.note,
      initialUndated: true,
      onPersist: (event) async {
        final String profileId =
            event.contextProfileId ?? ref.read(activeProfileIdProvider);
        _service(ref).createPersonalEvent(
          event.copyWith(isUndated: true),
          ProfileScopedEventRepository(
            ref.read(eventRepositoryProvider),
            profileId,
          ),
        );
        ref.read(calendarEventsProvider.notifier).reload();
      },
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, AppEvent event) {
    final access = ref.read(activeProfileAccessProvider);
    return EventPreviewSheet.show(
      context: context,
      event: event,
      activeProfileId: ref.read(activeProfileIdProvider),
      onEventUpdated: access.canEditEvents
          ? (updated) {
              _service(ref).updatePersonalEvent(
                source: event,
                updated: updated,
              );
              ref.read(calendarEventsProvider.notifier).reload();
            }
          : null,
      onSave: access.canEditEvents
          ? (
              updated, {
              recurrenceScope = RecurrenceEditScope.wholeSeries,
            }) async {
              _service(ref).persistEditedEvent(
                original: event,
                updated: updated,
                recurrenceScope: recurrenceScope,
              );
              ref.read(calendarEventsProvider.notifier).reload();
            }
          : null,
      onDelete: access.canDeleteEvents
          ? (target) async {
              _service(ref).deletePersonalEvent(target);
              ref.read(calendarEventsProvider.notifier).reload();
            }
          : null,
    );
  }
}
