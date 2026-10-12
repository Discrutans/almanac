import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DragUpdateDetails allows 2D delta without primaryDelta', () {
    // Mirrors week_selection_frame resize handle construction.
    const delta = Offset(3, -12);
    expect(
      () => DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: delta,
      ),
      returnsNormally,
    );
  });

  test('DragUpdateDetails rejects primaryDelta with non-zero cross axis', () {
    const delta = Offset(0.2, -8);
    expect(
      () => DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: delta,
        primaryDelta: delta.dy,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
