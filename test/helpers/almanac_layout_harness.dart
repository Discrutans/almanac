import 'package:almanac/app/app.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [FakeViewPadding] is stored in physical pixels.
FakeViewPadding logicalViewPadding(
  WidgetTester tester, {
  double top = 0,
  double bottom = 0,
  double left = 0,
  double right = 0,
}) {
  final dpr = tester.view.devicePixelRatio;
  return FakeViewPadding(
    top: top * dpr,
    bottom: bottom * dpr,
    left: left * dpr,
    right: right * dpr,
  );
}

/// Календарная оболочка Almanac в заданном «устройстве» для layout-тестов.
Future<void> pumpAlmanacShell(
  WidgetTester tester, {
  required Size size,
  FakeViewPadding padding = const FakeViewPadding(),
  FakeViewPadding viewInsets = const FakeViewPadding(),
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final store = await LocalDataStore.openInMemory();
  store.bindPersistence();

  tester.view.physicalSize = Size(
    size.width * tester.view.devicePixelRatio,
    size.height * tester.view.devicePixelRatio,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  tester.view.viewInsets = viewInsets;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  await tester.binding.setSurfaceSize(size);

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [localDataStoreProvider.overrideWithValue(store)],
      child: const AlmanacApp(),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> expectModesWithoutOverflow(WidgetTester tester) async {
  expect(find.text('Месяц'), findsOneWidget);

  await tester.tap(find.text('Неделя'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Список'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Год'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Месяц'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
