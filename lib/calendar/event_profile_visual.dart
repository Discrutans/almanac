import 'package:flutter/material.dart';
import '../core/theme/almanac_tokens.dart';
import 'calendar_types.dart';

/// Событие принадлежит другому (не активному) профилю в split-view.
bool isForeignProfileEvent(AppEvent event, String activeProfileId) {
  final profileId = event.contextProfileId;
  return profileId != null && profileId != activeProfileId;
}

bool shouldMarkProfileOwnership(Set<String> visibleProfileIds) {
  return visibleProfileIds.length > 1;
}

/// Цвет полоски/маркера. Базовый ARGB сохраняется для фильтра.
Color eventMarkerColor(
  AppEvent event,
  String activeProfileId, {
  Color? accentEnd,
}) {
  final base = !isForeignProfileEvent(event, activeProfileId)
      ? event.color
      : event.color.withValues(alpha: 0.42);
  if (accentEnd == null) return base;
  return AlmanacBrand.resolveEventAccentColor(base, accentEnd);
}

Color eventSurfaceTint(
  AppEvent event,
  String activeProfileId, {
  double alpha = 0.16,
}) {
  final resolved = isForeignProfileEvent(event, activeProfileId)
      ? alpha * 0.55
      : alpha;
  return event.color.withValues(alpha: resolved);
}

/// Прозрачность карточки (фильтр по цвету применяется отдельно).
double eventProfileCardOpacity(AppEvent event, String activeProfileId) {
  return isForeignProfileEvent(event, activeProfileId) ? 0.78 : 1.0;
}

Color eventBackgroundAccent(
  AppEvent event,
  String activeProfileId, {
  double alpha = 0.12,
  Color? accentEnd,
}) {
  final resolved = isForeignProfileEvent(event, activeProfileId)
      ? alpha * 0.55
      : alpha;
  final tint = event.color.withValues(alpha: resolved);
  if (accentEnd == null) return tint;
  return AlmanacBrand.resolveEventAccentColor(tint, accentEnd);
}
