import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/almanac_layout_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iPhone SE 320×568 portrait does not overflow', (tester) async {
    await pumpAlmanacShell(tester, size: const Size(320, 568));
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('compact Android 360×780 does not overflow', (tester) async {
    await pumpAlmanacShell(tester, size: const Size(360, 780));
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('iPhone with Dynamic Island padding keeps chrome in safe area', (
    tester,
  ) async {
    const padding = FakeViewPadding(top: 59, bottom: 34);
    await pumpAlmanacShell(
      tester,
      size: const Size(393, 852),
      padding: padding,
    );

    final nav = tester.getTopLeft(find.text('Месяц'));
    expect(nav.dy, greaterThanOrEqualTo(59));
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('tall Android 412×915 with camera cutout does not overflow', (
    tester,
  ) async {
    await pumpAlmanacShell(
      tester,
      size: const Size(412, 915),
      padding: const FakeViewPadding(top: 40, bottom: 24),
    );
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('tablet 768×1024 does not overflow', (tester) async {
    await pumpAlmanacShell(tester, size: const Size(768, 1024));
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('desktop 1280×800 does not overflow', (tester) async {
    await pumpAlmanacShell(tester, size: const Size(1280, 800));
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('landscape phone 844×390 does not overflow', (tester) async {
    await pumpAlmanacShell(
      tester,
      size: const Size(844, 390),
      padding: const FakeViewPadding(left: 47, right: 47, bottom: 21),
    );
    expect(find.text('Месяц'), findsOneWidget);
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('dark theme shell does not overflow', (tester) async {
    await pumpAlmanacShell(
      tester,
      size: const Size(390, 844),
      brightness: Brightness.dark,
    );
    await expectModesWithoutOverflow(tester);
  });

  testWidgets('large text scale 1.6 does not overflow calendar chrome', (
    tester,
  ) async {
    await pumpAlmanacShell(tester, size: const Size(360, 780), textScale: 1.6);
    expect(find.text('Месяц'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard viewInsets keep month view laid out', (tester) async {
    await pumpAlmanacShell(
      tester,
      size: const Size(390, 844),
      viewInsets: const FakeViewPadding(bottom: 336),
    );
    expect(find.text('Месяц'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
