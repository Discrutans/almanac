import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/calendar/calendar_month_grid.dart';
import 'package:almanac/calendar/widgets/week/week_drop_hit_test.dart';

void main() {
  test('weekCarouselDropTargetAt maps viewport position to day lane', () {
    const columnWidth = 120.0;
    final focusedMonth = DateTime(2026, 6, 1);
    final laneDates = monthGridDates(focusedMonth);
    final selectedDate = DateTime(2026, 6, 17);

    final viewport = _FakeViewportBox(
      size: const Size(columnWidth * 3, 400),
      globalOrigin: const Offset(100, 200),
    );

    final mondayScroll = columnWidth * 14;
    final monday = weekCarouselDropTargetAt(
      globalPosition: const Offset(100 + 60, 300),
      viewportBox: viewport,
      scrollOffset: mondayScroll,
      columnWidth: columnWidth,
      laneDates: laneDates,
      selectedDate: selectedDate,
    );
    expect(monday?.ghost, isFalse);
    expect(monday?.date, DateTime(2026, 6, 15));

    final wednesday = weekCarouselDropTargetAt(
      globalPosition: const Offset(100 + 180, 300),
      viewportBox: viewport,
      scrollOffset: columnWidth * 15,
      columnWidth: columnWidth,
      laneDates: laneDates,
      selectedDate: selectedDate,
    );
    expect(wednesday?.date, DateTime(2026, 6, 17));

    final ghostSunday = weekCarouselDropTargetAt(
      globalPosition: const Offset(100 + 60, 300),
      viewportBox: viewport,
      scrollOffset: 0,
      columnWidth: columnWidth,
      laneDates: laneDates,
      selectedDate: selectedDate,
    );
    expect(ghostSunday?.ghost, isTrue);
    expect(ghostSunday?.isGridEdgePrevious, isTrue);
    expect(ghostSunday?.date, DateTime(2026, 6, 1));
  });
}

class _FakeViewportBox extends RenderBox {
  _FakeViewportBox({required Size size, required this.globalOrigin}) {
    _size = size;
  }

  late Size _size;
  final Offset globalOrigin;

  @override
  Size get size => _size;

  Matrix4 get transform =>
      Matrix4.translationValues(globalOrigin.dx, globalOrigin.dy, 0);

  @override
  Offset globalToLocal(Offset point, {RenderObject? ancestor}) {
    return point - globalOrigin;
  }
}
