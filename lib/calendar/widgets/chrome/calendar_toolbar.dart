import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/ui/adaptive.dart';
import '../../../state/agenda_collapse_notifier.dart';
import '../../../state/calendar_filter_providers.dart';
import '../../../state/calendar_navigation_notifier.dart';
import '../../../state/calendar_toolbar_providers.dart';
import '../../calendar_today_visibility.dart';
import '../../../state/app_providers.dart';
import '../../../state/calendar_events_notifier.dart';
import '../../../state/session_pending_providers.dart';
import '../../../core/theme/almanac_motion.dart';
import '../../../core/ui/almanac_sheets.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';
import 'calendar_mode_switcher.dart';
import 'event_color_filter_bar.dart';
import '../../../inbox/inbox_sheet_body.dart';

/// Панель под шапкой: режим календаря, входящие и фильтр по цвету.
class CalendarToolbar extends ConsumerStatefulWidget {
  const CalendarToolbar({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.events,
  });

  final CalendarMode mode;
  final ValueChanged<CalendarMode> onModeChanged;
  final List<AppEvent> events;

  @override
  ConsumerState<CalendarToolbar> createState() => _CalendarToolbarState();
}

class _CalendarToolbarState extends ConsumerState<CalendarToolbar> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  var _filterOpen = false;

  @override
  void dispose() {
    _removeOverlay(markDirty: false);
    super.dispose();
  }

  void _removeOverlay({bool markDirty = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_filterOpen && markDirty && mounted) {
      setState(() => _filterOpen = false);
    } else {
      _filterOpen = false;
    }
  }

  void _toggleFilterOverlay() {
    if (_filterOpen) {
      _removeOverlay();
      return;
    }

    final colors = collectEventColorValues(widget.events);
    if (colors.length <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _filterOpen) return;
      _showOverlay();
    });
  }

  void _showOverlay() {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final scheme = Theme.of(overlayContext).colorScheme;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: Material(
                elevation: 12,
                shadowColor: scheme.shadow.withValues(alpha: 0.22),
                borderRadius: AlmanacRadius.card,
                clipBehavior: Clip.antiAlias,
                color: scheme.surfaceContainerHigh,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: EventColorFilterPopup(
                    events: widget.events,
                    onClose: _removeOverlay,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() => _filterOpen = true);
  }

  bool _showTodayButton(
    CalendarNavigationState nav,
    CalendarToolbarViewState? viewState,
  ) {
    return shouldShowCalendarTodayButton(
      mode: widget.mode,
      nav: nav,
      today: DateTime.now(),
      viewState: viewState,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final nav = ref.watch(calendarNavigationProvider);
    final navNotifier = ref.read(calendarNavigationProvider.notifier);
    final viewState = ref.watch(calendarToolbarViewStateProvider);
    final remotePending = ref.watch(remoteSessionPendingListProvider);
    final localPending = ref.watch(pendingBookingsProvider);
    final undated = ref.watch(undatedInboxEventsProvider);
    final inboxCount =
        remotePending.length + localPending.length + undated.length;
    final access = ref.watch(activeProfileAccessProvider);
    final showInbox = !access.canBookOnly;
    final colorFilter = ref.watch(eventColorFilterProvider);
    final colors = collectEventColorValues(widget.events);
    final canFilter = colors.length > 1;
    final filterActive = _filterOpen || colorFilter.isNotEmpty;
    final showToday = _showTodayButton(nav, viewState);
    final agendaMonthKeyValue = agendaMonthKey(nav.focusedMonth);
    final agendaDaysWithEvents = widget.mode == CalendarMode.agenda
        ? agendaDaysWithEventsForMonth(widget.events, nav.focusedMonth)
        : const <DateTime>[];
    final showAgendaCollapse =
        widget.mode == CalendarMode.agenda && agendaDaysWithEvents.isNotEmpty;
    ref.watch(
      agendaCollapseProvider.select(
        (state) => state.collapsedByMonth[agendaMonthKeyValue],
      ),
    );
    final allAgendaExpanded = showAgendaCollapse
        ? ref
              .read(agendaCollapseProvider.notifier)
              .areAllExpanded(agendaMonthKeyValue, agendaDaysWithEvents)
        : true;

    final gap = context.isMobileWidth ? AlmanacSpacing.xxs : AlmanacSpacing.xxs;

    final iconStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size(40, 40),
      padding: const EdgeInsets.all(8),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CalendarModeSwitcher(
            mode: widget.mode,
            onModeChanged: widget.onModeChanged,
          ),
        ),
        AlmanacAnimatedToolbarSlot(
          visible: showInbox,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: gap),
              _InboxButton(count: inboxCount, style: iconStyle),
            ],
          ),
        ),
        AlmanacAnimatedToolbarSlot(
          visible: showAgendaCollapse,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AlmanacSpacing.xxs),
              IconButton(
                style: iconStyle,
                tooltip: allAgendaExpanded
                    ? l10n.agendaCollapseAll
                    : l10n.agendaExpandAll,
                onPressed: () {
                  ref
                      .read(agendaCollapseProvider.notifier)
                      .toggleCollapseAll(
                        agendaMonthKeyValue,
                        agendaDaysWithEvents,
                      );
                },
                icon: Icon(
                  allAgendaExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                ),
              ),
            ],
          ),
        ),
        AlmanacAnimatedToolbarSlot(
          visible: showToday,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AlmanacSpacing.xxs),
              IconButton(
                style: iconStyle,
                tooltip: l10n.jumpToTodayChip,
                onPressed: navNotifier.goToToday,
                icon: const Icon(Icons.today_rounded),
              ),
            ],
          ),
        ),
        AlmanacAnimatedToolbarSlot(
          visible: canFilter,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: AlmanacSpacing.xxs),
              CompositedTransformTarget(
                link: _layerLink,
                child: IconButton(
                  style: iconStyle,
                  tooltip: colorFilter.isEmpty
                      ? l10n.colorFilterTooltip
                      : l10n.colorFilterActiveLabel(colorFilter.length),
                  onPressed: _toggleFilterOverlay,
                  icon: Badge(
                    isLabelVisible: colorFilter.isNotEmpty,
                    label: Text('${colorFilter.length}'),
                    child: Icon(
                      filterActive
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InboxButton extends ConsumerWidget {
  const _InboxButton({required this.count, this.style});

  final int count;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      style: style,
      tooltip: l10n.inboxTooltip,
      onPressed: () {
        ref.read(pendingBookingsProvider.notifier).refresh();
        refreshRemoteSessionPending(ref);
        PendingBookingsSheet.show(context);
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.inbox_outlined),
      ),
    );
  }
}

/// Sheet с pending-бронированиями (не занимает место в основном layout).
class PendingBookingsSheet {
  PendingBookingsSheet._();

  static Future<void> show(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showAlmanacSheet<void>(
      context: context,
      placement: AlmanacSheetPlacement.bottom,
      title: l10n.inboxTooltip,
      size: AlmanacPanelSize.hug,
      child: const InboxSheetBody(),
    );
  }
}
