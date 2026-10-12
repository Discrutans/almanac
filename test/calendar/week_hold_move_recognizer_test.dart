import 'package:almanac/calendar/widgets/week/week_hold_move_recognizer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required WeekHoldMoveRecognizer Function() create,
}) {
  return MaterialApp(
    home: Scaffold(
      body: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          WeekHoldMoveRecognizer:
              GestureRecognizerFactoryWithHandlers<WeekHoldMoveRecognizer>(
            create,
            (_) {},
          ),
        },
        child: const ColoredBox(
          color: Colors.white,
          child: SizedBox(width: 300, height: 400),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hold fires onHoldAccepted after delay when pointer stays still', (
    tester,
  ) async {
    var accepted = false;
    await tester.pumpWidget(
      _harness(
        create: () => WeekHoldMoveRecognizer(
          delay: const Duration(milliseconds: 40),
          allowPointer: (_) => true,
        )..onHoldAccepted = (_) => accepted = true,
      ),
    );

    final gesture = await tester.startGesture(const Offset(150, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(accepted, isTrue);
    await gesture.up();
  });

  testWidgets('movement before hold delay rejects', (tester) async {
    var rejected = false;
    await tester.pumpWidget(
      _harness(
        create: () => WeekHoldMoveRecognizer(
          delay: const Duration(milliseconds: 200),
          allowPointer: (_) => true,
        )..onHoldRejected = () => rejected = true,
      ),
    );

    final gesture = await tester.startGesture(const Offset(150, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 48));
    await tester.pump();
    expect(rejected, isTrue);
    await gesture.up();
  });

  testWidgets('allowPointer false never accepts hold', (tester) async {
    var accepted = false;
    await tester.pumpWidget(
      _harness(
        create: () => WeekHoldMoveRecognizer(
          delay: Duration.zero,
          allowPointer: (_) => false,
        )..onHoldAccepted = (_) => accepted = true,
      ),
    );

    final gesture = await tester.startGesture(const Offset(150, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(accepted, isFalse);
    await gesture.up();
  });
}
