import 'package:flutter/material.dart';
import '../../../core/theme/almanac_tokens.dart';
import '../../calendar_types.dart';
import '../../event_profile_visual.dart';

/// Сортирует события: сначала активный профиль, затем по времени.

List<AppEvent> prioritizeEventsForProfile(
  List<AppEvent> events,

  String activeProfileId,
) {
  final sorted = List<AppEvent>.from(events);

  sorted.sort((a, b) {
    final aActive = _belongsToProfile(a, activeProfileId);

    final bActive = _belongsToProfile(b, activeProfileId);

    if (aActive != bActive) return aActive ? -1 : 1;

    return a.start.compareTo(b.start);
  });

  return sorted;
}

/// Событие для акцента ячейки (рамка, фон) — из активного профиля.

AppEvent? accentEventForProfile(List<AppEvent> events, String activeProfileId) {
  if (events.isEmpty) return null;

  final prioritized = prioritizeEventsForProfile(events, activeProfileId);

  return prioritized.first;
}

bool _belongsToProfile(AppEvent event, String profileId) {
  return event.contextProfileId == null || event.contextProfileId == profileId;
}

/// Форма маркеров событий в ячейке даты.
enum EventDayMarkerStyle {
  /// Горизонтальные полоски (список, agenda).
  bars,

  /// Круглые точки (месяц, год).
  dots,
}

/// Цветные маркеры событий в ячейке даты.
class EventDayMarkers extends StatelessWidget {
  const EventDayMarkers({
    super.key,

    required this.events,

    this.maxVisible = 3,

    this.compact = false,

    this.selected = false,

    this.dense = false,

    this.activeProfileId,

    this.showOverflowCount = true,
    this.style = EventDayMarkerStyle.bars,
    this.showPlusWhenOverflow = false,
  });

  final List<AppEvent> events;

  final int maxVisible;

  final bool compact;

  final bool selected;

  final bool dense;

  final String? activeProfileId;

  final bool showOverflowCount;
  final EventDayMarkerStyle style;
  final bool showPlusWhenOverflow;

  Color _markerColor(AppEvent event, ProfileHighlightColors highlight) {
    return activeProfileId == null
        ? AlmanacBrand.resolveEventAccentColor(event.color, highlight.accentEnd)
        : eventMarkerColor(
            event,
            activeProfileId!,
            accentEnd: highlight.accentEnd,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final highlight = context.profileHighlight;
    final colorScheme = Theme.of(context).colorScheme;

    final ordered = activeProfileId == null
        ? events
        : prioritizeEventsForProfile(events, activeProfileId!);

    final visible = ordered.take(maxVisible).toList();

    final hidden = events.length - visible.length;

    if (style == EventDayMarkerStyle.dots) {
      return _EventDotsRow(
        visible: visible,
        hidden: hidden,
        compact: compact,
        dense: dense,
        selected: selected,
        colorScheme: colorScheme,
        highlight: highlight,
        showOverflowCount: showOverflowCount,
        showPlusWhenOverflow: showPlusWhenOverflow,
        colorFor: (event) => _markerColor(event, highlight),
      );
    }

    final barHeight = dense ? 2.5 : (compact ? 3.0 : 4.0);

    final gap = dense ? 0.8 : (compact ? 1.2 : 1.8);

    return Column(
      mainAxisSize: MainAxisSize.min,

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) SizedBox(height: gap),

          _EventBar(
            color: _markerColor(visible[i], highlight),
            height: barHeight,
            selected: selected,
          ),
        ],

        if (showOverflowCount && hidden > 0) ...[
          SizedBox(height: gap),

          Text(
            '+$hidden',

            textAlign: TextAlign.center,

            maxLines: 1,

            overflow: TextOverflow.clip,

            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: dense ? 6.0 : (compact ? 7.5 : 9),

              height: 1,

              fontWeight: FontWeight.w700,

              color: selected
                  ? highlight.accentEnd
                  : colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}

class _EventDotsRow extends StatelessWidget {
  const _EventDotsRow({
    required this.visible,
    required this.hidden,
    required this.compact,
    required this.dense,
    required this.selected,
    required this.colorScheme,
    required this.highlight,
    required this.showOverflowCount,
    required this.showPlusWhenOverflow,
    required this.colorFor,
  });

  final List<AppEvent> visible;
  final int hidden;
  final bool compact;
  final bool dense;
  final bool selected;
  final ColorScheme colorScheme;
  final ProfileHighlightColors highlight;
  final bool showOverflowCount;
  final bool showPlusWhenOverflow;
  final Color Function(AppEvent event) colorFor;

  double get _dotSize => eventDotMarkerSize(compact: compact, dense: dense);

  double get _gap => dense ? 1.5 : (compact ? 2.0 : 3.0);

  double get _overflowFontSize =>
      eventDotOverflowFontSize(compact: compact, dense: dense);

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) SizedBox(width: _gap),
            Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: colorFor(visible[i]),
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (hidden > 0 && showOverflowCount) ...[
            SizedBox(width: _gap),
            Text(
              '+$hidden',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: _overflowFontSize,
                height: 1,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: selected
                    ? highlight.accentEnd
                    : colorScheme.onSurface.withValues(alpha: 0.78),
              ),
            ),
          ] else if (hidden > 0 && showPlusWhenOverflow) ...[
            SizedBox(width: _gap * 0.75),
            Text(
              '+',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: dense ? 7.0 : 8.0,
                height: 1,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Размер круглой точки в ячейке даты.
double eventDotMarkerSize({required bool compact, bool dense = false}) {
  if (dense) return 4.0;
  if (compact) return 7.0;
  return 9.0;
}

/// Кегль подписи «+N» у точек.
double eventDotOverflowFontSize({required bool compact, bool dense = false}) {
  if (dense) return 7.0;
  if (compact) return 10.0;
  return 11.5;
}

/// Высота полосы маркеров под ячейкой даты.
double eventDayMarkersBandHeight({
  required bool compact,
  EventDayMarkerStyle style = EventDayMarkerStyle.bars,
  int maxVisible = 3,
  bool dense = false,
}) {
  if (style == EventDayMarkerStyle.dots) {
    final dot = eventDotMarkerSize(compact: compact, dense: dense);
    final font = eventDotOverflowFontSize(compact: compact, dense: dense);
    final content = dot > font ? dot : font;
    return content + (dense ? 1 : (compact ? 2 : 3));
  }

  final barHeight = compact ? 3.0 : 4.0;
  final gap = compact ? 1.2 : 1.8;
  return barHeight * maxVisible + gap * (maxVisible - 1);
}

class _EventBar extends StatelessWidget {
  const _EventBar({
    required this.color,
    required this.height,
    required this.selected,
  });

  final Color color;
  final double height;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height * 2),
      ),
      child: SizedBox(height: height),
    );
  }
}

/// Фоновая подсветка дня с событиями.

Color eventDayBackgroundTint({
  required List<AppEvent> events,

  required ColorScheme colorScheme,

  required bool selected,

  required bool inFocusedMonth,

  String? activeProfileId,

  Color selectionColor = AlmanacBrand.accentEnd,

  Color? accentEnd,
}) {
  if (selected) {
    return selectionColor.withValues(alpha: 0.1);
  }

  if (events.isEmpty || !inFocusedMonth) return Colors.transparent;

  final accent = activeProfileId == null
      ? events.first
      : accentEventForProfile(events, activeProfileId);

  if (accent == null) return Colors.transparent;

  final tint = activeProfileId == null
      ? AlmanacBrand.resolveEventAccentColor(
          accent.color.withValues(alpha: 0.12),
          accentEnd ?? selectionColor,
        )
      : eventBackgroundAccent(
          accent,
          activeProfileId,
          accentEnd: accentEnd ?? selectionColor,
        );

  return Color.alphaBlend(
    tint,
    colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
  );
}
