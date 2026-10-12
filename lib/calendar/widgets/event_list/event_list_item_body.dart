part of '../event_list_item.dart';

class _SlidableEventCard extends StatelessWidget {
  const _SlidableEventCard({
    required this.event,
    required this.activeProfileId,
    required this.shellColor,
    this.profileLabel,
    required this.expanded,
    required this.hasChecklist,
    required this.checklist,
    required this.showInlineActions,
    required this.dense,
    required this.isScheduleEvent,
    this.onOpen,
    required this.onEventUpdated,
    this.onShiftQuickAction,
    this.onMoveToDate,
    required this.onToggleExpanded,
    required this.checklistBuilder,
  });

  final AppEvent event;
  final String activeProfileId;
  final Color shellColor;
  final String? profileLabel;
  final bool expanded;
  final bool hasChecklist;
  final List<ChecklistItem> checklist;
  final bool showInlineActions;
  final bool dense;
  final bool isScheduleEvent;
  final VoidCallback? onOpen;
  final ValueChanged<AppEvent> onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final EventMoveToDateCallback? onMoveToDate;
  final VoidCallback? onToggleExpanded;
  final Widget Function(List<ChecklistItem> items, int level) checklistBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final slidable = Slidable.of(context);
    final slide = slidable?.animation.value ?? 0.0;
    final slideAmount = slide.abs().clamp(0.0, 1.0);

    final background = Color.lerp(
      shellColor,
      eventSurfaceTint(event, activeProfileId, alpha: 0.12),
      slideAmount,
    )!;
    final borderColor = Color.lerp(
      colorScheme.outlineVariant.withValues(alpha: 0.18),
      eventMarkerColor(event, activeProfileId).withValues(alpha: 0.4),
      slideAmount,
    )!;

    return AnimatedBuilder(
      animation: slidable?.animation ?? kAlwaysCompleteAnimation,
      builder: (context, child) {
        return Material(
          color: background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: borderColor,
                  width: slideAmount > 0 ? 2 : 0,
                ),
                right: BorderSide(
                  color: borderColor,
                  width: slideAmount > 0 ? 2 : 0,
                ),
              ),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!dense)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AlmanacSpacing.sm,
                AlmanacSpacing.xs,
                AlmanacSpacing.sm,
                0,
              ),
              child: PomodoroLiveIndicator(
                event: event,
                onEventUpdated: onEventUpdated,
                expandToWidth: true,
              ),
            ),
          _EventCardTitleRow(
            event: event,
            activeProfileId: activeProfileId,
            dense: dense,
            hasChecklist: hasChecklist,
            expanded: expanded,
            onOpen: onOpen,
            onToggleExpanded: onToggleExpanded,
            onMoveToDate: onMoveToDate,
          ),
          _EventCardDetails(
            event: event,
            profileLabel: profileLabel,
            dense: dense,
            showInlineActions: showInlineActions,
            isScheduleEvent: isScheduleEvent,
            hasChecklist: hasChecklist,
            onOpen: onOpen,
            onMoveToDate: onMoveToDate,
          ),
          if (dense && event.hasPomodoro)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AlmanacSpacing.sm,
                0,
                AlmanacSpacing.sm,
                AlmanacSpacing.xxs,
              ),
              child: PomodoroLiveIndicator(
                event: event,
                onEventUpdated: onEventUpdated,
                expandToWidth: true,
              ),
            ),
          if (onShiftQuickAction != null)
            ScheduleQuickActionsBar(
              event: event,
              onAction: onShiftQuickAction!,
              dense: dense,
            ),
          if (expanded && hasChecklist)
            Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? AlmanacSpacing.xs : AlmanacSpacing.sm,
                dense ? AlmanacSpacing.xxs : 0,
                dense ? AlmanacSpacing.xs : AlmanacSpacing.sm,
                dense ? AlmanacSpacing.xxs : AlmanacSpacing.sm,
              ),
              child: checklistBuilder(checklist, 0),
            ),
          if (expanded && !hasChecklist)
            Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? AlmanacSpacing.xs : AlmanacSpacing.sm,
                0,
                dense ? AlmanacSpacing.xs : AlmanacSpacing.sm,
                AlmanacSpacing.sm,
              ),
              child: Text(
                l10n.emptyChecklist,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.almanacColors.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventCardTitleRow extends StatelessWidget {
  const _EventCardTitleRow({
    required this.event,
    required this.activeProfileId,
    required this.dense,
    required this.hasChecklist,
    required this.expanded,
    this.onOpen,
    this.onToggleExpanded,
    this.onMoveToDate,
  });

  final AppEvent event;
  final String activeProfileId;
  final bool dense;
  final bool hasChecklist;
  final bool expanded;
  final VoidCallback? onOpen;
  final VoidCallback? onToggleExpanded;
  final EventMoveToDateCallback? onMoveToDate;

  Future<void> _handleMove(BuildContext context) async {
    if (onMoveToDate == null) return;
    final target = await MoveEventToDateSheet.pick(
      context: context,
      initialDate: event.start,
    );
    if (target == null) return;
    onMoveToDate!(event, target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final marker = eventMarkerColor(event, activeProfileId);
    final display = EventDisplayInfo.from(event, l10n);
    final pad = dense ? AlmanacSpacing.xs : AlmanacSpacing.sm;
    final iconGap = dense ? AlmanacSpacing.xs : AlmanacSpacing.sm;
    final iconSize = dense ? 28.0 : 32.0;
    final canMove =
        onMoveToDate != null &&
        (event.capabilities.canDragInWeekView || event.isUndated);
    final timeLabel =
        event.kind == CalendarEntryKind.event ||
            event.entrySource.isScheduleRelated
        ? formatEventTimeRange(event)
        : null;
    final amountLabel = event.kind == CalendarEntryKind.savingsGoal &&
            event.savingsTargetAmount != null
        ? formatMoney(event.savingsTargetAmount!)
        : null;
    final heading = timeLabel ?? amountLabel;
    final title = event.kind == CalendarEntryKind.note
        ? event.title
        : event.noteDisplayTitle;
    final progress = event.kind == CalendarEntryKind.checklist
        ? event.checklistProgress
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: AlmanacRadius.chip,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onOpen,
                    onLongPress: canMove ? () => _handleMove(context) : null,
                    borderRadius: AlmanacRadius.chip,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (heading != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AlmanacSpacing.xxs,
                            ),
                            child: Text(
                              heading,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                    height: 1.2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                        SizedBox(
                          height: AlmanacSizes.buttonHeight,
                          child: Row(
                            children: [
                              if (dense)
                                SizedBox(
                                  width: iconSize,
                                  child: Icon(
                                    display.listIcon,
                                    size: 20,
                                    color: marker,
                                  ),
                                )
                              else
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: marker,
                                    borderRadius: AlmanacRadius.control,
                                  ),
                                  child: SizedBox(
                                    width: iconSize,
                                    height: 32,
                                    child: Icon(
                                      _entryKindIcon(event.kind),
                                      color: AlmanacBrand.onFill(marker),
                                      size: 16,
                                    ),
                                  ),
                                ),
                              SizedBox(width: iconGap),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                ),
                              ),
                              if (progress != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AlmanacSpacing.xs,
                                  ),
                                  child: Text(
                                    l10n.checklistsCountShort(
                                      event.checklistCompletedCount,
                                      event.checklistTotalCount,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: marker,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              if (event.kind == CalendarEntryKind.note &&
                                  event.hasAttachments)
                                Icon(
                                  Icons.attach_file_outlined,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasChecklist && onToggleExpanded != null)
                AlmanacTappable(
                  onTap: onToggleExpanded,
                  child: Center(
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventCardDetails extends StatelessWidget {
  const _EventCardDetails({
    required this.event,
    required this.profileLabel,
    required this.dense,
    required this.showInlineActions,
    required this.isScheduleEvent,
    required this.hasChecklist,
    this.onOpen,
    this.onMoveToDate,
  });

  final AppEvent event;
  final String? profileLabel;
  final bool dense;
  final bool showInlineActions;
  final bool isScheduleEvent;
  final bool hasChecklist;
  final VoidCallback? onOpen;
  final EventMoveToDateCallback? onMoveToDate;

  Future<void> _handleMove(BuildContext context) async {
    if (onMoveToDate == null) return;
    final target = await MoveEventToDateSheet.pick(
      context: context,
      initialDate: event.start,
    );
    if (target == null) return;
    onMoveToDate!(event, target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitleLines = _buildEventSubtitleLines(
      context,
      l10n: l10n,
      event: event,
      profileLabel: profileLabel,
      showInlineActions: dense ? false : showInlineActions,
      isScheduleEvent: isScheduleEvent,
      omitEventTime: true,
      notesMaxLines: event.kind == CalendarEntryKind.note ? 3 : null,
      omitChecklistProgress:
          event.kind == CalendarEntryKind.checklist && hasChecklist,
    );
    final showIndicators = _EventFeatureIndicators.hasAny(
      event: event,
      isScheduleEvent: isScheduleEvent,
    );
    final autoNoteBody =
        event.kind == CalendarEntryKind.note && event.isAutoDerivedNoteTitle
        ? event.notes?.trim()
        : null;
    final hasAutoNoteBody = autoNoteBody != null && autoNoteBody.isNotEmpty;
    if (subtitleLines.isEmpty && !showIndicators && !hasAutoNoteBody) {
      return const SizedBox(height: AlmanacSpacing.xs);
    }

    final pad = dense ? AlmanacSpacing.xs : AlmanacSpacing.sm;
    final canMove =
        onMoveToDate != null &&
        (event.capabilities.canDragInWeekView || event.isUndated);
    final mutedStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.almanacColors.muted);

    return InkWell(
      onTap: onOpen,
      onLongPress: canMove ? () => _handleMove(context) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(pad, AlmanacSpacing.xxs, pad, pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasAutoNoteBody)
              Text(
                autoNoteBody,
                style: mutedStyle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (subtitleLines.isNotEmpty) ...[
              if (hasAutoNoteBody) const SizedBox(height: 2),
              ...[
                for (var i = 0; i < subtitleLines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 2),
                  subtitleLines[i],
                ],
              ],
            ],
            if (showIndicators) ...[
              const SizedBox(height: AlmanacSpacing.xxs),
              _EventFeatureIndicators(
                event: event,
                isScheduleEvent: isScheduleEvent,
                compact: dense ? false : !showInlineActions,
                timeRange:
                    !dense &&
                        !showInlineActions &&
                        event.kind == CalendarEntryKind.event
                    ? formatEventTimeRange(event)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

