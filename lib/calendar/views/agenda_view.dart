import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../state/agenda_collapse_notifier.dart';
import '../../state/calendar_navigation_notifier.dart';
import '../../state/calendar_toolbar_providers.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_card.dart';
import '../../core/ui/almanac_empty_state.dart';
import '../../core/ui/almanac_scroll.dart';
import '../../state/calendar_filter_providers.dart';
import '../../state/app_providers.dart';
import '../../state/remote_config_providers.dart';
import '../../sessions/session_creation/join_session_sheet.dart';
import '../calendar_event_index.dart';
import '../calendar_types.dart';
import '../widgets/agenda_day_snap.dart';
import '../widgets/event_list_item.dart';
import '../widgets/schedule_quick_actions_bar.dart';
import '../widgets/chrome/calendar_day_badge.dart';
import '../widgets/chrome/event_day_markers.dart';

part 'agenda/agenda_scroll_helpers.dart';
part 'agenda/agenda_scroll_logic.dart';
part 'agenda/agenda_day_section.dart';

/// Список событий месяца, сгруппированный по дням.
class AgendaCalendarView extends ConsumerStatefulWidget {
  const AgendaCalendarView({
    super.key,
    required this.focusedMonth,
    required this.selectedDate,
    required this.events,
    required this.onDateSelected,
    this.onDateLongPress,
    required this.onEditEvent,
    this.onViewEvent,
    required this.onDeleteEvent,
    required this.onCreateEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    this.onMoveToDate,
    required this.activeProfileId,
    this.scrollToTodayNonce = 0,
    this.colorFilter = const {},
    this.profileNamesById = const {},
    this.profileSeedColors = const {},
  });

  final DateTime focusedMonth;
  final DateTime selectedDate;
  final List<AppEvent> events;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onDateLongPress;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onViewEvent;
  final EventDeleteCallback onDeleteEvent;
  final VoidCallback onCreateEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final EventMoveToDateCallback? onMoveToDate;
  final String activeProfileId;
  final int scrollToTodayNonce;
  final Set<int> colorFilter;
  final Map<String, String> profileNamesById;
  final Map<String, Color> profileSeedColors;

  static List<DateTime> monthDates(DateTime focusedMonth) =>
      agendaMonthDates(focusedMonth);

  @override
  ConsumerState<AgendaCalendarView> createState() => _AgendaCalendarViewState();
}

class _AgendaCalendarViewState extends ConsumerState<AgendaCalendarView>
    with _AgendaScrollHelpers, _AgendaScrollLogic, _AgendaDaySectionBuilder {
  /// Как у колонки дня в недельном виде ([WeekDayColumn]).
  static const _daySectionPadding = EdgeInsets.fromLTRB(
    AlmanacSpacing.xxs,
    AlmanacSpacing.xs,
    AlmanacSpacing.xxs,
    AlmanacSpacing.sm,
  );

  static const _scrollToTodayLayoutSettleFrames = 1;
  static const _scrollToTodayMonthSettleFrames = 1;
  static const _maxScrollToTodayAttempts = 96;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: _initialScrollOffsetForPendingAgendaScroll(),
    );
    _scrollController.addListener(_attachScrollIdleListener);
    _scrollController.addListener(_onScrollControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollIdleListener();
      _updateTodayChipVisibility();
      _publishToolbarState();
      _maybeScrollToSelectedDay(freshMount: true);
    });
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollIdleChanged);
    _scrollController
      ..removeListener(_attachScrollIdleListener)
      ..removeListener(_onScrollControllerChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AgendaCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedMonth != oldWidget.focusedMonth) {
      _userScrolling = false;
      _ignoreNextCollapseAnchor = true;
      if (!_agendaScrollPending() &&
          widget.scrollToTodayNonce == oldWidget.scrollToTodayNonce &&
          _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateTodayChipVisibility();
        _publishToolbarState();
        if (_agendaScrollPending()) {
          _scheduleMaybeScrollToSelectedDay(freshMount: true);
        }
      });
    } else if (widget.selectedDate != oldWidget.selectedDate &&
        _agendaScrollPending()) {
      _scheduleMaybeScrollToSelectedDay();
    }
    if (widget.events != oldWidget.events ||
        widget.focusedMonth != oldWidget.focusedMonth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateTodayChipVisibility();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      calendarNavigationProvider.select((nav) => nav.agendaScrollPending),
      (previous, next) {
        if (next == true) {
          _scheduleMaybeScrollToSelectedDay();
        }
      },
    );
    ref.listen<Set<AgendaDayKey>?>(
      agendaCollapseProvider.select(
        (state) => state.collapsedByMonth[_agendaMonthKey],
      ),
      (previous, next) {
        if (previous == next) return;
        _onCollapseStateChanged();
      },
    );
    ref.watch(
      agendaCollapseProvider.select(
        (state) => state.collapsedByMonth[_agendaMonthKey],
      ),
    );

    final l10n = AppLocalizations.of(context);
    final access = ref.watch(activeProfileAccessProvider);
    final hasHttp = ref.watch(hasConfiguredServerProvider);
    final eventsIndex = _eventsIndexCache.of(widget.events);
    final agendaDays = _agendaDays();
    final filterActive = widget.colorFilter.isNotEmpty;
    final hasVisibleFilterMatches =
        !filterActive ||
        widget.events.any(
          (event) => eventMatchesColorFilter(event, widget.colorFilter),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        return AlmanacCard(
          child: SizedBox(
            height: constraints.maxHeight,
            child: agendaDays.isEmpty
                ? AlmanacEmptyState(
                    icon: filterActive && !hasVisibleFilterMatches
                        ? Icons.filter_alt_off_outlined
                        : Icons.date_range_outlined,
                    message: filterActive && !hasVisibleFilterMatches
                        ? '${l10n.colorFilterNoMatches}\n${l10n.colorFilterNoMatchesHint}'
                        : '${l10n.emptyAgendaMonthTitle}\n${l10n.emptyAgendaMonthHint}',
                    actionLabel: filterActive && !hasVisibleFilterMatches
                        ? null
                        : (access.canBookOnly && hasHttp
                              ? l10n.createEntryJoinSession
                              : l10n.addEvent),
                    onAction: filterActive && !hasVisibleFilterMatches
                        ? null
                        : (access.canBookOnly && hasHttp
                              ? () => JoinSessionSheet.show(context)
                              : widget.onCreateEvent),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: CustomScrollView(
                      controller: _scrollController,
                      cacheExtent: AlmanacScroll.calendarCacheExtent,
                      slivers: [
                        for (var index = 0; index < agendaDays.length; index++)
                          ..._buildAgendaDaySlivers(
                            context,
                            date: agendaDays[index],
                            index: index,
                            eventsIndex: eventsIndex,
                            daysWithEvents: agendaDays,
                          ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: AlmanacSpacing.md),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
