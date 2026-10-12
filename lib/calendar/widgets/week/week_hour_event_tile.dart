import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';
import '../../event_display_info.dart';
import '../../event_profile_visual.dart';
import '../../event_time_utils.dart';
import 'week_event_cell_contour.dart';
import 'week_hour_axis.dart';
import 'week_ui_tokens.dart';

/// Timed-событие: заливка ячеек сетки + компактный текст поверх.
/// Без [axis] (all-day) — обычная карточка.
class WeekHourEventTile extends StatelessWidget {
  const WeekHourEventTile({
    super.key,
    required this.event,
    required this.activeProfileId,
    required this.onTap,
    this.axis,
    this.startMinutes,
    this.endMinutes,
    this.profileSeedColor,
    this.profileLabel,
    this.locked = false,
    this.armed = false,
    this.contentMaxWidth,
  });

  final AppEvent event;
  final String activeProfileId;
  final VoidCallback onTap;
  final WeekHourAxis? axis;
  final int? startMinutes;
  final int? endMinutes;
  final Color? profileSeedColor;
  final String? profileLabel;
  final bool locked;
  final bool armed;

  /// When cascading, clip title/time to this width (fill can be wider).
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final markerColor = eventMarkerColor(event, activeProfileId);
    final foreign = isForeignProfileEvent(event, activeProfileId);
    final opacity = eventProfileCardOpacity(event, activeProfileId);
    final display = EventDisplayInfo.from(
      event,
      l10n,
      profileLabel: foreign ? profileLabel : null,
      omitEventTime: true,
      omitChecklistProgress: true,
      compactMetaLabels: true,
    );
    final showLock = locked && !armed;
    final isShift = event.isFromWorkSchedule;
    final tint = eventSurfaceTint(
      event,
      activeProfileId,
      alpha: isShift ? 0.55 : 0.42,
    );
    final surface = Color.alphaBlend(tint, scheme.surface);
    final gridAxis = axis;
    final start = startMinutes;
    final end = endMinutes;
    final useCellFill = gridAxis != null && start != null && end != null;
    final title = event.noteDisplayTitle;
    final tooltip = display.tooltipMessage(l10n);

    if (!useCellFill) {
      return Material(
        color: surface,
        elevation: armed ? AlmanacElevation.raised : 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.28),
        borderRadius: AlmanacRadius.control,
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: isShift ? 1 : (showLock ? opacity * 0.82 : opacity),
          child: InkWell(
            onTap: onTap,
            splashColor: markerColor.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
              child: _TileBody(
                scheme: scheme,
                showLock: showLock,
                lockLabel: l10n.weekEventLocked,
                title: title,
                timeText: event.isTimed ? event.startTime : null,
                titleMaxLines: 1,
                tooltip: tooltip,
              ),
            ),
          ),
        ),
      );
    }

    final originY = gridAxis.yForMinutes(start);
    final firstCell = weekHourSegmentsOverlappingRange(
      axis: gridAxis,
      startMinutes: start,
      endMinutes: end,
    ).firstOrNull;
    final contentTop = firstCell == null
        ? 0.0
        : (firstCell.y - originY).clamp(0.0, double.infinity);
    final spanHeight = (gridAxis.yForMinutes(end) - originY).clamp(
      kWeekHourMinEventHeight,
      gridAxis.totalHeight,
    );
    final hourH = gridAxis.hourHeight;
    final contentHeight = firstCell == null
        ? kWeekHourMinEventHeight
        : math.min(
            spanHeight,
            math.max(
              firstCell.height,
              hourH * (spanHeight >= hourH * 1.5 ? 2 : 1),
            ),
          );
    final narrow =
        contentMaxWidth != null &&
        contentMaxWidth! < WeekUiTokens.tileNarrowContentWidth;
    final hideText =
        contentMaxWidth != null &&
        contentMaxWidth! < WeekUiTokens.tileHideTextWidth;
    final titleMaxLines =
        !narrow && spanHeight >= hourH * WeekUiTokens.tileTwoLineHours ? 2 : 1;
    final String? timeText;
    if (!event.isTimed ||
        narrow ||
        spanHeight < WeekUiTokens.tileHideTimeHeightPx) {
      timeText = null;
    } else if (spanHeight >= hourH * WeekUiTokens.tileRangeTimeHours) {
      timeText = formatEventTimeRange(event);
    } else {
      timeText = event.startTime;
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        splashColor: markerColor.withValues(alpha: 0.12),
        child: Opacity(
          opacity: isShift ? 1 : (showLock ? opacity * 0.82 : opacity),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: WeekEventCellContourPainter(
                    axis: gridAxis,
                    startMinutes: start,
                    endMinutes: end,
                    color: surface,
                    originY: originY,
                  ),
                ),
              ),
              if (!hideText)
                Positioned(
                  top: contentTop,
                  left: 4,
                  width: contentMaxWidth == null
                      ? null
                      : (contentMaxWidth! - 4).clamp(8.0, double.infinity),
                  right: contentMaxWidth == null ? 4 : null,
                  height: contentHeight,
                  child: ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                      child: _TileBody(
                        scheme: scheme,
                        showLock: showLock && !narrow,
                        lockLabel: l10n.weekEventLocked,
                        title: title,
                        timeText: timeText,
                        titleMaxLines: titleMaxLines,
                        tooltip: tooltip,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.scheme,
    required this.showLock,
    required this.lockLabel,
    required this.timeText,
    required this.title,
    required this.titleMaxLines,
    required this.tooltip,
  });

  final ColorScheme scheme;
  final bool showLock;
  final String lockLabel;
  final String? timeText;
  final String title;
  final int titleMaxLines;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowLock = showLock && constraints.maxWidth >= 24;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (canShowLock) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.lock_outline,
                      size: 11,
                      color: scheme.onSurfaceVariant,
                      semanticLabel: lockLabel,
                    ),
                  ],
                ],
              ),
              if (timeText != null) ...[
                const SizedBox(height: 1),
                Text(
                  timeText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
