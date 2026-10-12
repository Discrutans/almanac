import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/event_time_utils.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';
import 'package:almanac/calendar/widgets/week/week_grid_slot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WeekGridSlot.movedTo keeps duration and clamps', () {
    final slot = WeekGridSlot(
      date: DateTime(2026, 9, 10),
      startMinutes: 10 * 60,
      endMinutes: 10 * 60 + 90,
    );
    final moved = slot.movedTo(
      date: DateTime(2026, 9, 11),
      startMinutes: 14 * 60 + 15,
    );
    expect(isSameCalendarDay(moved.date, DateTime(2026, 9, 11)), isTrue);
    expect(moved.startMinutes, 14 * 60 + 15);
    expect(moved.endMinutes, 14 * 60 + 15 + 90);
  });

  test('weekResolveSlotDrop accepts other day/time', () {
    final slot = WeekGridSlot(
      date: DateTime(2026, 9, 10),
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
    );
    final target = WeekDropTarget(
      date: DateTime(2026, 9, 12),
      columnIndex: 2,
      columnCount: 7,
      minutesOfDay: 16 * 60,
    );
    final resolved = weekResolveSlotDrop(slot: slot, target: target);
    expect(resolved.accepted, isTrue);
    expect(resolved.slot!.startMinutes, 16 * 60);
    expect(resolved.slot!.endMinutes, 17 * 60);
  });

  test('hour-floor retarget preserves duration (no 15-min drift)', () {
    final slot = WeekGridSlot(
      date: DateTime(2026, 9, 10),
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
    );
    final start = weekHourFloorMinutes(8 * 60 + 45);
    final moved = slot.movedTo(
      date: DateTime(2026, 9, 10),
      startMinutes: start,
    );
    expect(moved.startMinutes, 8 * 60);
    expect(moved.endMinutes, 9 * 60);
  });
}
