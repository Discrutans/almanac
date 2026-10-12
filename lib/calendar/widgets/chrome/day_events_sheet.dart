import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../state/app_providers.dart';
import '../../../state/calendar_events_notifier.dart';
import '../../../state/calendar_filter_providers.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../calendar_event_index.dart';
import '../../calendar_types.dart';
import '../event_list_item.dart';
import '../schedule_quick_actions_bar.dart';
import 'event_day_markers.dart';
import 'events_panel.dart';

/// Bottom sheet / top panel с событиями выбранного дня (без смены режима календаря).
class DayEventsSheet extends ConsumerWidget {
  const DayEventsSheet({
    super.key,
    required this.date,
    required this.activeProfileId,
    required this.onEditEvent,
    this.onViewEvent,
    required this.onDeleteEvent,
    required this.onCreateEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    required this.onOpenWeekView,
    this.showSwipeHint = false,
    this.onSwipeHintDismissed,
  });

  final DateTime date;
  final String activeProfileId;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onViewEvent;
  final EventDeleteCallback onDeleteEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final VoidCallback onOpenWeekView;
  final bool showSwipeHint;
  final VoidCallback? onSwipeHintDismissed;

  static Future<void> show({
    required BuildContext context,
    required DateTime date,
    required String activeProfileId,
    required ValueChanged<AppEvent> onEditEvent,
    ValueChanged<AppEvent>? onViewEvent,
    required EventDeleteCallback onDeleteEvent,
    required VoidCallback onCreateEvent,
    String? createLabel,
    required ValueChanged<AppEvent> onEventUpdated,
    ShiftQuickActionCallback? onShiftQuickAction,
    required VoidCallback onOpenWeekView,
    bool showSwipeHint = false,
    VoidCallback? onSwipeHintDismissed,
  }) {
    final l10n = AppLocalizations.of(context);

    return showAlmanacSheet<void>(
      context: context,
      title: l10n.fullDate(date),
      size: AlmanacPanelSize.cover,
      useSafeArea: false,
      footer: Builder(
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: onCreateEvent,
                icon: Icon(
                  createLabel == null
                      ? Icons.add
                      : Icons.event_available_outlined,
                ),
                label: Text(createLabel ?? l10n.addEvent),
              ),
              const SizedBox(height: AlmanacSpacing.xs),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenWeekView();
                },
                icon: const Icon(Icons.view_week_outlined),
                label: Text(l10n.openWeekViewAction),
              ),
            ],
          );
        },
      ),
      child: DayEventsSheet(
        date: date,
        activeProfileId: activeProfileId,
        onEditEvent: onEditEvent,
        onViewEvent: onViewEvent,
        onDeleteEvent: onDeleteEvent,
        onCreateEvent: onCreateEvent,
        onEventUpdated: onEventUpdated,
        onShiftQuickAction: onShiftQuickAction,
        onOpenWeekView: onOpenWeekView,
        showSwipeHint: showSwipeHint,
        onSwipeHintDismissed: onSwipeHintDismissed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsByDay = ref.watch(calendarEventsByDayProvider);
    final colorFilter = ref.watch(eventColorFilterProvider);
    final profilesState = ref.watch(contextProfilesProvider);
    final profileNamesById = profilesState.isSplitView
        ? {for (final p in profilesState.profiles) p.id: p.name}
        : const <String, String>{};
    final dayEvents = filterEventsByColor(
      prioritizeEventsForProfile(
        List<AppEvent>.from(eventsForDay(eventsByDay, date))
          ..sort((a, b) => a.start.compareTo(b.start)),
        activeProfileId,
      ),
      colorFilter,
    );

    return EventsPanel(
      date: date,
      events: dayEvents,
      activeProfileId: activeProfileId,
      profileNamesById: profileNamesById,
      colorFilterActive: colorFilter.isNotEmpty,
      showDateHeader: false,
      showSwipeHint: showSwipeHint,
      onSwipeHintDismissed: onSwipeHintDismissed,
      shrinkWrap: true,
      showCreateAction: false,
      enableSwipe: !ref.watch(activeProfileAccessProvider).canBookOnly,
      onViewEvent: onViewEvent,
      onEditEvent: onEditEvent,
      onDeleteEvent: onDeleteEvent,
      onCreateEvent: onCreateEvent,
      onEventUpdated: onEventUpdated,
      onShiftQuickAction: onShiftQuickAction,
    );
  }
}
