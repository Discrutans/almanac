part of '../agenda_view.dart';

mixin _AgendaDaySectionBuilder
    on
        ConsumerState<AgendaCalendarView>,
        _AgendaScrollHelpers,
        _AgendaScrollLogic {
  String? _profileLabelFor(BuildContext context, AppEvent event) {
    if (widget.profileNamesById.isEmpty) return null;
    final profileId = event.contextProfileId;
    if (profileId == null || profileId == widget.activeProfileId) return null;
    final name = widget.profileNamesById[profileId];
    if (name == null) return null;
    return AppLocalizations.of(context).eventProfileLabel(name);
  }

  /// Заголовки всегда в дереве (для snap), карточки событий — лениво.
  List<Widget> _buildAgendaDaySlivers(
    BuildContext context, {
    required DateTime date,
    required int index,
    required Map<DateTime, List<AppEvent>> eventsIndex,
    required List<DateTime> daysWithEvents,
  }) {
    final collapsed = _isDayCollapsed(date);
    final allDayEvents = eventsForDay(eventsIndex, date);
    final events = collapsed
        ? const <AppEvent>[]
        : prioritizeEventsForProfile(
            List<AppEvent>.from(allDayEvents)
              ..sort((a, b) => a.start.compareTo(b.start)),
            widget.activeProfileId,
          );
    final eventCount = allDayEvents.length;
    final horizontal = AlmanacSpacing.xxs;
    final top = index == 0
        ? _AgendaCalendarViewState._daySectionPadding.top
        : AlmanacSpacing.sm;
    final bottom = _AgendaCalendarViewState._daySectionPadding.bottom;

    final slivers = <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, top, horizontal, 0),
        sliver: SliverToBoxAdapter(
          child: RepaintBoundary(
            child: _AgendaDayHeader(
              key: _headerKeyFor(date),
              date: date,
              selected: isSameCalendarDay(date, widget.selectedDate),
              eventCount: eventCount,
              collapsed: collapsed,
              onToggle: () => _toggleDayCollapsed(date, daysWithEvents),
            ),
          ),
        ),
      ),
    ];

    if (collapsed) {
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottom)));
      return slivers;
    }

    if (events.isEmpty && allDayEvents.isNotEmpty) {
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AlmanacSpacing.xxs,
            horizontal,
            bottom,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              AppLocalizations.of(context).colorFilterNoMatches,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    if (events.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottom)));
      return slivers;
    }

    slivers.add(
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AlmanacSpacing.xxs,
          horizontal,
          bottom,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, eventIndex) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: eventIndex < events.length - 1 ? 6 : 0,
                ),
                child: RepaintBoundary(
                  child: EventListItem(
                    key: ValueKey(
                      'agenda-${date.toIso8601String()}-${events[eventIndex].id}',
                    ),
                    event: events[eventIndex],
                    activeProfileId: widget.activeProfileId,
                    profileLabel: _profileLabelFor(context, events[eventIndex]),
                    compactActions: true,
                    dense: true,
                    tapOpensEditor: true,
                    enableSwipe: false,
                    checklistsAlwaysExpanded: true,
                    onEditEvent: widget.onEditEvent,
                    onViewEvent: widget.onViewEvent,
                    onDeleteEvent: widget.onDeleteEvent,
                    onEventUpdated: widget.onEventUpdated,
                    onShiftQuickAction: widget.onShiftQuickAction,
                    onMoveToDate: widget.onMoveToDate,
                  ),
                ),
              );
            },
            childCount: events.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false,
          ),
        ),
      ),
    );

    return slivers;
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({
    super.key,
    required this.date,
    required this.selected,
    required this.eventCount,
    required this.collapsed,
    required this.onToggle,
  });

  final DateTime date;
  final bool selected;
  final int eventCount;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final highlight = context.profileHighlight;
    final isToday = isSameCalendarDay(date, DateTime.now());

    return Semantics(
      button: true,
      label: collapsed ? l10n.agendaExpandDay : l10n.agendaCollapseDay,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: AlmanacRadius.control,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AlmanacSpacing.xxs),
            child: Row(
              children: [
                CalendarDayBadge(
                  date: date,
                  selected: selected,
                  interactive: false,
                  highlightToday: false,
                ),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AlmanacSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: highlight.accentStart.withValues(alpha: 0.12),
                      borderRadius: AlmanacRadius.chip,
                    ),
                    child: Text(
                      l10n.jumpToTodayChip,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: highlight.accentEnd,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (eventCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AlmanacSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: AlmanacRadius.chip,
                    ),
                    child: Text(
                      '$eventCount',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: AlmanacSpacing.xxs),
                Icon(
                  collapsed
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 22,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
