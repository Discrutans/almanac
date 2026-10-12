import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../../core/ui/almanac_fit_text.dart';
import '../../calendar_types.dart';
import '../../calendar_entry_capabilities.dart';
import '../../event_display_info.dart';
import '../../event_profile_visual.dart';
import '../../event_time_utils.dart';
import '../schedule_quick_actions_bar.dart';
import '../../../pomodoro/pomodoro_live_indicator.dart';

/// Legacy list-card for week column (historical). Live UI: [WeekHourEventTile].
@Deprecated('Use WeekHourEventTile for the hour-grid week view')
class WeekEventTile extends StatelessWidget {
  const WeekEventTile({
    super.key,
    required this.event,
    required this.activeProfileId,
    required this.onTap,
    this.onEventUpdated,
    this.onShiftQuickAction,
    this.profileSeedColor,
    this.profileLabel,
    this.fillHeight = false,
  });

  final AppEvent event;
  final String activeProfileId;
  final VoidCallback onTap;
  final ValueChanged<AppEvent>? onEventUpdated;
  final ShiftQuickActionCallback? onShiftQuickAction;
  final Color? profileSeedColor;
  final String? profileLabel;
  final bool fillHeight;

  static const _titleSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final markerColor = eventMarkerColor(event, activeProfileId);
    final foreign = isForeignProfileEvent(event, activeProfileId);
    final opacity = eventProfileCardOpacity(event, activeProfileId);
    final isChecklist = event.kind == CalendarEntryKind.checklist;
    final display = EventDisplayInfo.from(
      event,
      l10n,
      profileLabel: foreign ? profileLabel : null,
      omitEventTime: true,
      omitChecklistProgress: true,
      compactMetaLabels: true,
    );
    final showShiftActions =
        onShiftQuickAction != null &&
        event.capabilities.editsCreateScheduleOverride;
    final showForeign = foreign && profileLabel != null;
    final markerChips = [
      for (final chip in display.metaChips)
        if (chip.icon != Icons.attach_file_outlined) chip,
    ];
    final showMeta =
        markerChips.isNotEmpty ||
        showForeign ||
        event.hasAttachments ||
        (event.incomeAmount != null && event.incomeAmount! > 0);

    return Opacity(
      opacity: opacity,
      child: Material(
        color: eventSurfaceTint(event, activeProfileId),
        borderRadius: AlmanacRadius.control,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              splashColor: markerColor.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: fillHeight
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(display.listIcon, size: 18, color: markerColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Tooltip(
                            message: display.tooltipMessage(l10n),
                            preferBelow: false,
                            child: AlmanacFitText(
                              text: display.title,
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: _titleSize,
                                    height: 1.15,
                                    letterSpacing: -0.15,
                                  ) ??
                                  TextStyle(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: _titleSize,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.isTimed) ...[
                      const SizedBox(height: 4),
                      _InlineTime(event: event, fontSize: _titleSize),
                    ],
                    if (isChecklist) ...[
                      const SizedBox(height: 4),
                      AlmanacFitText(
                        text: l10n.checklistsProgress(
                          event.checklistCompletedCount,
                          event.checklistTotalCount,
                        ),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: markerColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              height: 1.2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ) ??
                            TextStyle(
                              color: markerColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                      ),
                    ],
                    if (fillHeight) const Spacer(),
                    if (showMeta) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                        chips: markerChips,
                        profileLabel: showForeign ? profileLabel : null,
                        profileSeedColor: profileSeedColor,
                        imageCount: event.imageAttachmentCount,
                        fileCount: event.fileAttachmentCount,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showShiftActions)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ScheduleQuickActionsBar(
                  event: event,
                  onAction: onShiftQuickAction!,
                  dense: true,
                ),
              ),
            if (event.hasPomodoro)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: PomodoroLiveIndicator(
                  event: event,
                  onEventUpdated: onEventUpdated,
                  compact: true,
                  expandToWidth: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Время того же кегля, что и название карточки.
class _InlineTime extends StatelessWidget {
  const _InlineTime({required this.event, required this.fontSize});

  final AppEvent event;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = eventHasKnownEndTime(event)
        ? '${event.startTime} – ${event.endTime}'
        : event.startTime;

    return AlmanacFitText(
      text: text,
      style:
          Theme.of(context).textTheme.titleSmall?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
            letterSpacing: -0.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ) ??
          TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1.15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.chips,
    required this.imageCount,
    required this.fileCount,
    this.profileLabel,
    this.profileSeedColor,
  });

  final List<EventMetaChipInfo> chips;
  final int imageCount;
  final int fileCount;
  final String? profileLabel;
  final Color? profileSeedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasAttachments = imageCount > 0 || fileCount > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final chip in chips)
                chip.label == null
                    ? _MetaIcon(
                        icon: chip.icon,
                        color: _chipColor(context, chip.icon, scheme),
                        tooltip: chip.tooltip,
                      )
                    : _MetaLabeled(
                        icon: chip.icon,
                        label: chip.label!,
                        color: _chipColor(context, chip.icon, scheme),
                        tooltip: chip.tooltip,
                      ),
              if (profileLabel != null)
                _ProfileTag(
                  label: profileLabel!,
                  color: profileSeedColor ?? scheme.primary,
                ),
            ],
          ),
        ),
        if (hasAttachments) ...[
          const SizedBox(width: 6),
          _AttachmentMarks(
            imageCount: imageCount,
            fileCount: fileCount,
            color: scheme.secondary,
          ),
        ],
      ],
    );
  }

  Color _chipColor(BuildContext context, IconData icon, ColorScheme scheme) {
    if (icon == Icons.repeat_rounded) {
      return context.profileHighlight.warmAccent;
    }
    if (icon == Icons.payments_outlined) {
      return context.almanacColors.success;
    }
    if (icon == Icons.event_available_outlined) {
      return scheme.tertiary;
    }
    return scheme.primary;
  }
}

class _AttachmentMarks extends StatelessWidget {
  const _AttachmentMarks({
    required this.imageCount,
    required this.fileCount,
    required this.color,
  });

  final int imageCount;
  final int fileCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageCount > 0)
          _CountMark(
            icon: Icons.photo_outlined,
            count: imageCount,
            color: color,
          ),
        if (imageCount > 0 && fileCount > 0) const SizedBox(width: 6),
        if (fileCount > 0)
          _CountMark(
            icon: Icons.attach_file_outlined,
            count: fileCount,
            color: color,
          ),
      ],
    );
  }
}

class _CountMark extends StatelessWidget {
  const _CountMark({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.9)),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 14, color: color.withValues(alpha: 0.9)),
    );
  }
}

class _MetaLabeled extends StatelessWidget {
  const _MetaLabeled({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.9)),
          const SizedBox(width: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AlmanacRadius.chip,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 9.5,
          ),
        ),
      ),
    );
  }
}
