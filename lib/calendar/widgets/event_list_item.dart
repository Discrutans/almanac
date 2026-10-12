import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/almanac_tokens.dart';
import '../../core/ui/almanac_card.dart';
import '../../core/ui/almanac_tappable.dart';
import '../calendar_types.dart';
import '../calendar_entry_capabilities.dart';
import '../event_time_utils.dart';
import '../event_profile_visual.dart';
import '../event_display_info.dart';
import 'forms/checklist_tree.dart';
import '../../pomodoro/pomodoro_live_indicator.dart';
import 'schedule_quick_actions_bar.dart';
import 'forms/move_event_to_date_sheet.dart';

part 'event_list/event_list_item_body.dart';
part 'event_list/event_list_item_actions.dart';

typedef EventDeleteCallback = Future<bool> Function(AppEvent event);
typedef EventMoveToDateCallback = void Function(AppEvent event, DateTime date);

/// Карточка события со swipe-действиями и раскрываемым чек-листом.
class EventListItem extends StatefulWidget {
  const EventListItem({
    super.key,
    required this.event,
    required this.onEditEvent,
    this.onViewEvent,
    required this.onDeleteEvent,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    this.onMoveToDate,
    this.compactActions = false,
    this.dense = false,
    this.tapOpensEditor = true,
    this.enableSwipe = true,
    this.checklistsAlwaysExpanded = false,
    this.dimmed = false,
    required this.activeProfileId,
    this.profileLabel,
  });

  final AppEvent event;
  final ValueChanged<AppEvent> onEditEvent;
  final ValueChanged<AppEvent>? onViewEvent;
  final EventDeleteCallback onDeleteEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final EventMoveToDateCallback? onMoveToDate;
  final bool compactActions;
  final bool dense;
  final bool tapOpensEditor;
  final bool enableSwipe;
  final bool checklistsAlwaysExpanded;
  final bool dimmed;
  final String activeProfileId;
  final String? profileLabel;

  @override
  State<EventListItem> createState() => _EventListItemState();
}

class _EventListItemState extends State<EventListItem> {
  late List<ChecklistItem> _checklist;
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _checklist = widget.event.checklist;
    _expanded = widget.event.kind == CalendarEntryKind.checklist;
  }

  @override
  void didUpdateWidget(covariant EventListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.checklist != widget.event.checklist) {
      _checklist = widget.event.checklist;
    }
    if (widget.checklistsAlwaysExpanded &&
        widget.event.kind == CalendarEntryKind.checklist) {
      _expanded = true;
    }
  }

  VoidCallback? get _onOpen {
    if (widget.onViewEvent != null) {
      return () => widget.onViewEvent!(widget.event);
    }
    if (widget.tapOpensEditor) {
      return () => widget.onEditEvent(widget.event);
    }
    return null;
  }

  Future<bool> _handleDelete() => widget.onDeleteEvent(widget.event);

  Future<void> _runDeleteAction(BuildContext actionContext) async {
    await _handleDelete();
    if (actionContext.mounted) {
      await Slidable.of(actionContext)?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasChecklist =
        widget.event.kind == CalendarEntryKind.checklist &&
        _checklist.isNotEmpty;
    final l10n = AppLocalizations.of(context);
    final showInlineActions = !widget.compactActions;
    final caps = widget.event.capabilities;
    final danger = context.almanacColors.danger;
    final shellColor = colorScheme.surfaceContainerHighest;
    final cardOpacity = widget.dimmed
        ? 0.38
        : eventProfileCardOpacity(widget.event, widget.activeProfileId);

    final canMove =
        widget.onMoveToDate != null &&
        (caps.canDragInWeekView || widget.event.isUndated);

    final card = _SlidableEventCard(
      event: widget.event,
      activeProfileId: widget.activeProfileId,
      profileLabel: widget.profileLabel,
      shellColor: shellColor,
      expanded: _expanded,
      hasChecklist: hasChecklist,
      checklist: _checklist,
      showInlineActions: showInlineActions,
      dense: widget.dense,
      isScheduleEvent: widget.event.entrySource.isScheduleRelated,
      onOpen: _onOpen,
      onEventUpdated: widget.onEventUpdated,
      onShiftQuickAction: widget.onShiftQuickAction,
      onMoveToDate: widget.onMoveToDate,
      onToggleExpanded: hasChecklist && !widget.checklistsAlwaysExpanded
          ? () => setState(() => _expanded = !_expanded)
          : null,
      checklistBuilder: _buildChecklist,
    );

    return Opacity(
      opacity: cardOpacity,
      child: AlmanacCard(
        padding: EdgeInsets.zero,
        child: widget.enableSwipe
            ? Slidable(
                key: ValueKey('slidable-${widget.event.id}'),
                closeOnScroll: true,
                startActionPane: canMove
                    ? ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: 0.28,
                        dragDismissible: false,
                        openThreshold: 0.12,
                        children: [
                          SlidableAction(
                            flex: 1,
                            autoClose: true,
                            onPressed: (actionContext) async {
                              final target = await MoveEventToDateSheet.pick(
                                context: actionContext,
                                initialDate: widget.event.start,
                              );
                              if (target != null) {
                                widget.onMoveToDate!(widget.event, target);
                              }
                              if (actionContext.mounted) {
                                await Slidable.of(actionContext)?.close();
                              }
                            },
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            icon: Icons.event_available_outlined,
                            label: l10n.scheduleOnDayAction,
                          ),
                        ],
                      )
                    : null,
                endActionPane: caps.canSwipeDelete
                    ? ActionPane(
                        motion: const BehindMotion(),
                        extentRatio: 0.22,
                        dragDismissible: false,
                        openThreshold: 0.12,
                        dismissible: DismissiblePane(
                          confirmDismiss: _handleDelete,
                          closeOnCancel: true,
                          onDismissed: () {},
                        ),
                        children: [
                          SlidableAction(
                            flex: 1,
                            autoClose: true,
                            onPressed: _runDeleteAction,
                            backgroundColor: danger,
                            foregroundColor: colorScheme.onError,
                            icon: Icons.delete_outline,
                            label: l10n.swipeToDelete,
                          ),
                        ],
                      )
                    : null,
                child: card,
              )
            : card,
      ),
    );
  }

  Widget _buildChecklist(List<ChecklistItem> items, int level) {
    final entries = flattenChecklistTree(items, depth: level);
    final compact = widget.dense;
    final l10n = AppLocalizations.of(context);
    final total = widget.event.checklistTotalCount;
    final completed = widget.event.checklistCompletedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact && total > 0) ...[
          CompactChecklistProgress(
            completed: completed,
            total: total,
            color: widget.event.color,
            label: l10n.checklistsProgress(completed, total),
          ),
          const SizedBox(height: AlmanacSpacing.xxs),
        ],
        ...entries.map((entry) {
          final item = entry.item;
          return ChecklistListItemTile(
            entry: entry,
            accentColor: widget.event.color,
            compact: compact,
            onToggle: (value) => _toggleChecklistItem(item.id),
          );
        }),
      ],
    );
  }

  void _toggleChecklistItem(String id) {
    setState(() {
      _checklist = _toggleItems(id, _checklist);
      widget.onEventUpdated(widget.event.copyWith(checklist: _checklist));
    });
  }

  List<ChecklistItem> _toggleItems(String id, List<ChecklistItem> items) {
    return items.map((item) => _toggleItem(id, item)).toList();
  }

  ChecklistItem _toggleItem(String id, ChecklistItem item) {
    if (item.id == id) {
      return item.copyWith(completed: !item.completed);
    }

    return item.copyWith(
      children: item.children.map((child) {
        return _toggleItem(id, child);
      }).toList(),
    );
  }
}
