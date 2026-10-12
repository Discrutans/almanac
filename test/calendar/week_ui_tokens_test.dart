import 'package:almanac/calendar/widgets/week/week_ui_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview is weaker than slot and armed frames', () {
    expect(
      WeekUiTokens.previewFillAlpha,
      lessThan(WeekUiTokens.armedFillAlpha),
    );
    expect(
      WeekUiTokens.armedFillAlpha,
      lessThan(WeekUiTokens.slotFillAlpha),
    );
    expect(
      WeekUiTokens.previewBorderWidth,
      lessThan(WeekUiTokens.slotBorderWidth),
    );
    // Readable on cell fills after hideEmpty Y-drag regression.
    expect(WeekUiTokens.previewFillAlpha, greaterThanOrEqualTo(0.14));
  });

  test('ghost and dragging opacities stay in readable range', () {
    expect(WeekUiTokens.ghostOpacity, inInclusiveRange(0.2, 0.5));
    expect(WeekUiTokens.draggingSourceOpacity, inInclusiveRange(0.15, 0.4));
    expect(WeekUiTokens.frameDraggingOpacity, inInclusiveRange(0.15, 0.4));
  });

  test('tile density thresholds are ordered', () {
    expect(
      WeekUiTokens.tileTwoLineHours,
      lessThan(WeekUiTokens.tileRangeTimeHours),
    );
    expect(WeekUiTokens.tileHideTimeHeightPx, greaterThan(0));
    expect(WeekUiTokens.tileNarrowContentWidth, greaterThan(0));
  });
}
