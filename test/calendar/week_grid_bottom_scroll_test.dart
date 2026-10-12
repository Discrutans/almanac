import 'package:almanac/calendar/widgets/week/week_carousel_drag_autoscroll.dart';
import 'package:almanac/calendar/widgets/week/week_hour_axis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bottom-align pad is zero when axis fills viewport', () {
    expect(
      weekTimedBottomAlignPad(axisHeight: 600, viewportHeight: 500),
      0,
    );
    expect(
      weekTimedBottomAlignPad(axisHeight: 400, viewportHeight: 500),
      100,
    );
  });

  test('content Y maps through bottom-align pad to axis minutes', () {
    final axis = WeekHourAxis.fromEvents(
      events: const [],
      hideEmptyHours: false,
      expanded: true,
      hourHeight: 60,
    );
    const viewport = 800.0;
    final pad = weekTimedBottomAlignPad(
      axisHeight: axis.totalHeight,
      viewportHeight: viewport,
    );
    // First hour starts at contentY == pad.
    expect(
      weekTimedMinutesForContentY(
        axis: axis,
        contentY: pad,
        viewportHeight: viewport,
      ),
      0,
    );
    expect(
      weekTimedMinutesForContentY(
        axis: axis,
        contentY: pad + 60,
        viewportHeight: viewport,
        snap: true,
      ),
      60,
    );
  });

  testWidgets('autoscroller emits vertical delta at timed bottom edge', (
    tester,
  ) async {
    final viewportKey = GlobalKey();
    final deltas = <double>[];
    late WeekCarouselDragAutoScroller scroller;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: viewportKey,
            width: 400,
            height: 600,
            child: const ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    scroller = WeekCarouselDragAutoScroller(
      viewportKey: viewportKey,
      horizontalEnabled: false,
      timedTopInset: () => 80,
      onVerticalScrollBy: deltas.add,
      maxSpeed: 14,
      edgeZone: 56,
    );
    addTearDown(scroller.dispose);

    final box = viewportKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    // Near bottom of timed area (below header inset).
    scroller.updateDragPosition(
      Offset(origin.dx + 200, origin.dy + 600 - 10),
      horizontalEnabled: false,
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(deltas, isNotEmpty);
    expect(deltas.every((d) => d > 0), isTrue);

    scroller.stop();
    deltas.clear();

    // Near top of timed area.
    scroller.updateDragPosition(
      Offset(origin.dx + 200, origin.dy + 80 + 10),
      horizontalEnabled: false,
    );
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(deltas, isNotEmpty);
    expect(deltas.every((d) => d < 0), isTrue);
    scroller.stop();
  });

  testWidgets('autoscroller still emits horizontal delta at side edge', (
    tester,
  ) async {
    final viewportKey = GlobalKey();
    final controller = ScrollController();
    final hDeltas = <double>[];
    final vDeltas = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: viewportKey,
            width: 400,
            height: 600,
            child: ListView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              children: const [
                SizedBox(width: 2000, height: 600),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scroller = WeekCarouselDragAutoScroller(
      viewportKey: viewportKey,
      scrollController: controller,
      onScrollBy: hDeltas.add,
      onVerticalScrollBy: vDeltas.add,
      timedTopInset: () => 0,
      edgeZone: 56,
      maxSpeed: 14,
    );
    addTearDown(scroller.dispose);

    final box = viewportKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    scroller.updateDragPosition(Offset(origin.dx + 10, origin.dy + 300));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(hDeltas, isNotEmpty);
    expect(hDeltas.every((d) => d < 0), isTrue);
    scroller.stop();
  });
}
