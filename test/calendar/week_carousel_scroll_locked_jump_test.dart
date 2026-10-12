import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carousel locks user scroll during drag (`NeverScrollableScrollPhysics`),
/// but edge autoscroll must still `jumpTo` and refresh the drop target.
void main() {
  testWidgets('jumpTo works while horizontal physics are locked', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 120,
            child: ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              itemBuilder: (_, i) => SizedBox(
                width: 100,
                child: Text('c$i'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    controller.jumpTo(250);
    await tester.pump();
    expect(controller.offset, 250);
  });
}
