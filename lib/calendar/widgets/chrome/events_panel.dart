import 'package:flutter/material.dart';
import '../../calendar_types.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_card.dart';
import '../../../core/ui/almanac_empty_state.dart';
import '../../../core/ui/almanac_feedback.dart';
import '../../../core/ui/almanac_scroll.dart';
import '../schedule_quick_actions_bar.dart';
import '../event_list_item.dart';

/// Нижняя область недели: выбранная дата и список событий.
class EventsPanel extends StatelessWidget {
  const EventsPanel({
    super.key,
    required this.date,
    required this.events,
    required this.onEditEvent,
    this.onViewEvent,
    required this.onDeleteEvent,
    required this.onCreateEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    required this.activeProfileId,
    this.profileNamesById = const {},
    this.colorFilterActive = false,
    this.showDateHeader = true,
    this.showSwipeHint = false,
    this.onSwipeHintDismissed,
    this.onRefresh,
    this.shrinkWrap = false,
    this.showCreateAction = true,
    this.createActionLabel,
    this.enableSwipe = true,
  });

  final DateTime date;
  final List<AppEvent> events;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onViewEvent;
  final EventDeleteCallback onDeleteEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final String activeProfileId;
  final Map<String, String> profileNamesById;
  final bool colorFilterActive;
  final bool showDateHeader;
  final bool showSwipeHint;
  final VoidCallback? onSwipeHintDismissed;
  final Future<void> Function()? onRefresh;
  final bool shrinkWrap;
  final bool showCreateAction;
  final String? createActionLabel;
  final bool enableSwipe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compactActions = AlmanacBreakpoints.isMobile(
      MediaQuery.sizeOf(context).width,
    );

    return AlmanacCard(
      child: Column(
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDateHeader) ...[
            Text(
              l10n.fullDate(date),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AlmanacSpacing.xs),
          ],
          if (showSwipeHint && events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AlmanacSpacing.xs),
              child: AlmanacHintBanner(
                icon: Icons.swipe_rounded,
                message: l10n.swipeActionsHint,
                dismissLabel: l10n.hintDismiss,
                onDismiss: onSwipeHintDismissed ?? () {},
              ),
            ),
          if (shrinkWrap)
            ..._buildListContent(
              context,
              l10n: l10n,
              compactActions: compactActions,
            )
          else
            Expanded(
              child: events.isEmpty
                  ? _emptyState(l10n)
                  : RefreshIndicator(
                      onRefresh: onRefresh ?? () async {},
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        cacheExtent: AlmanacScroll.listCacheExtent,
                        slivers: _eventSlivers(
                          context,
                          l10n: l10n,
                          compactActions: compactActions,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildListContent(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool compactActions,
  }) {
    if (events.isEmpty) {
      return [_emptyState(l10n)];
    }
    return [
      if (compactActions)
        Padding(
          padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
          child: Text(
            l10n.tapEventToEdit,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.almanacColors.muted,
            ),
          ),
        ),
      Text(
        l10n.eventsForSelectedDate,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: AlmanacSpacing.xs),
      for (var i = 0; i < events.length; i++) ...[
        if (i > 0) const SizedBox(height: AlmanacSpacing.xs),
        _eventTile(context, events[i], compactActions: compactActions),
      ],
    ];
  }

  List<Widget> _eventSlivers(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool compactActions,
  }) {
    return [
      if (compactActions)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AlmanacSpacing.xxs),
            child: Text(
              l10n.tapEventToEdit,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.almanacColors.muted,
              ),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Text(
          l10n.eventsForSelectedDate,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AlmanacSpacing.xs)),
      SliverList.separated(
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(height: AlmanacSpacing.xs),
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child: _eventTile(
              context,
              events[index],
              compactActions: compactActions,
            ),
          );
        },
      ),
    ];
  }

  Widget _emptyState(AppLocalizations l10n) {
    return AlmanacEmptyState(
      message: colorFilterActive ? l10n.colorFilterNoMatches : l10n.noEvents,
      actionLabel: showCreateAction && !colorFilterActive
          ? (createActionLabel ?? l10n.addEvent)
          : null,
      onAction: showCreateAction && !colorFilterActive ? onCreateEvent : null,
    );
  }

  Widget _eventTile(
    BuildContext context,
    AppEvent event, {
    required bool compactActions,
  }) {
    final l10n = AppLocalizations.of(context);
    final profileId = event.contextProfileId;
    final profileLabel =
        profileNamesById.isEmpty ||
            profileId == null ||
            profileId == activeProfileId
        ? null
        : l10n.eventProfileLabel(profileNamesById[profileId] ?? profileId);
    return EventListItem(
      key: ValueKey(event.id),
      event: event,
      activeProfileId: activeProfileId,
      profileLabel: profileLabel,
      compactActions: compactActions,
      onEditEvent: onEditEvent,
      onViewEvent: onViewEvent,
      onDeleteEvent: onDeleteEvent,
      onEventUpdated: onEventUpdated,
      onShiftQuickAction: onShiftQuickAction,
      enableSwipe: enableSwipe,
    );
  }
}
