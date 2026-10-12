import 'package:almanac/core/theme/almanac_tokens.dart';
import 'package:almanac/core/ui/almanac_panel_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'panel max width is full-bleed on phones and capped on larger screens',
    () {
      expect(AlmanacPanelLayout.maxWidth(390), 390);
      expect(AlmanacPanelLayout.maxWidth(800), AlmanacPanelLayout.formMaxWidth);
      expect(
        AlmanacPanelLayout.maxWidth(1280, compact: true),
        AlmanacPanelLayout.compactMaxWidth,
      );
      expect(
        AlmanacPanelLayout.maxWidth(1280),
        AlmanacPanelLayout.formMaxWidth,
      );
      expect(
        AlmanacPanelLayout.maxWidth(800),
        lessThan(AlmanacSizes.maxContentWidth),
      );
    },
  );

  test('cover panels fill the window', () {
    expect(
      AlmanacPanelLayout.maxHeightFactor(390, size: AlmanacPanelSize.cover),
      1,
    );
    expect(
      AlmanacPanelLayout.maxHeightFactor(1280, size: AlmanacPanelSize.cover),
      1,
    );
    expect(
      AlmanacPanelLayout.maxWidth(1280, size: AlmanacPanelSize.cover),
      1280,
    );
    expect(
      AlmanacPanelLayout.outerPadding(
        screenWidth: 1280,
        isBottom: true,
        size: AlmanacPanelSize.cover,
      ),
      EdgeInsets.zero,
    );
    expect(
      AlmanacPanelLayout.borderRadius(
        isBottom: true,
        size: AlmanacPanelSize.cover,
      ),
      BorderRadius.zero,
    );
  });

  test('expanded panels are shorter on tablet and desktop than on phones', () {
    final phone = AlmanacPanelLayout.maxHeightFactor(390);
    final tablet = AlmanacPanelLayout.maxHeightFactor(800);
    final desktop = AlmanacPanelLayout.maxHeightFactor(1280);
    expect(phone, greaterThan(tablet));
    expect(tablet, greaterThan(desktop));
    expect(
      AlmanacPanelLayout.maxHeightFactor(390, size: AlmanacPanelSize.hug),
      lessThan(phone),
    );
  });

  test('bottom sheets go edge-to-edge on phones and inset on tablets', () {
    expect(
      AlmanacPanelLayout.outerPadding(screenWidth: 390, isBottom: true),
      EdgeInsets.zero,
    );
    expect(
      AlmanacPanelLayout.outerPadding(screenWidth: 800, isBottom: true).left,
      AlmanacSpacing.md,
    );
    expect(
      AlmanacPanelLayout.outerPadding(screenWidth: 1280, isBottom: false).left,
      AlmanacSpacing.lg,
    );
  });

  test('top and bottom sheets share the same corner radius size', () {
    expect(
      AlmanacPanelLayout.borderRadius(isBottom: true),
      AlmanacRadius.sheetTop,
    );
    expect(
      AlmanacPanelLayout.borderRadius(isBottom: false),
      AlmanacRadius.sheetBottom,
    );
    expect(
      AlmanacRadius.sheetTop.topLeft.x,
      AlmanacRadius.sheetBottom.bottomLeft.x,
    );
  });
}
