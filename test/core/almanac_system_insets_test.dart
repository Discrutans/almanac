import 'package:almanac/core/ui/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bottom inset uses the larger of nav bar and keyboard', () {
    const barOnly = MediaQueryData(
      size: Size(390, 844),
      viewPadding: EdgeInsets.only(bottom: 48),
    );
    expect(AlmanacSystemInsets.bottom(barOnly), 48);

    const keyboard = MediaQueryData(
      size: Size(390, 844),
      viewPadding: EdgeInsets.only(bottom: 48),
      viewInsets: EdgeInsets.only(bottom: 280),
    );
    expect(AlmanacSystemInsets.bottom(keyboard), 280);

    const empty = MediaQueryData(size: Size(390, 844));
    expect(AlmanacSystemInsets.bottom(empty), 0);
    expect(AlmanacSystemInsets.top(empty), 0);
  });

  test('top inset reads status bar viewPadding', () {
    const notch = MediaQueryData(
      size: Size(390, 844),
      viewPadding: EdgeInsets.only(top: 59, bottom: 34),
    );
    expect(AlmanacSystemInsets.top(notch), 59);
    expect(AlmanacSystemInsets.bottom(notch), 34);
  });
}
