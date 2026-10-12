import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../calendar/calendar_types.dart';

/// Активный фильтр по цветам событий (ARGB32). Пустой набор — показывать все.
final eventColorFilterProvider = StateProvider<Set<int>>((ref) => {});

void clearEventColorFilter(WidgetRef ref) {
  ref.read(eventColorFilterProvider.notifier).state = {};
}

void toggleEventColorFilter(WidgetRef ref, int colorValue) {
  final current = {...ref.read(eventColorFilterProvider)};
  if (current.contains(colorValue)) {
    current.remove(colorValue);
  } else {
    current.add(colorValue);
  }
  ref.read(eventColorFilterProvider.notifier).state = current;
}

List<int> collectEventColorValues(List<AppEvent> events) {
  final values = <int>{};
  for (final event in events) {
    values.add(event.color.toARGB32());
  }
  return values.toList()..sort();
}

bool eventMatchesColorFilter(AppEvent event, Set<int> filter) {
  if (filter.isEmpty) return true;
  return filter.contains(event.color.toARGB32());
}

List<AppEvent> filterEventsByColor(List<AppEvent> events, Set<int> filter) {
  if (filter.isEmpty) return events;
  return events.where((e) => eventMatchesColorFilter(e, filter)).toList();
}

/// День показывает события при активном фильтре, если хотя бы одно совпадает.
bool dayHasVisibleEventsForColorFilter(
  List<AppEvent> dayEvents,
  Set<int> filter,
) {
  if (filter.isEmpty) return dayEvents.isNotEmpty;
  return dayEvents.any((event) => eventMatchesColorFilter(event, filter));
}
