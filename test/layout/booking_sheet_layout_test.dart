import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/sessions/session_creation/create_booking_session_sheet.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/almanac_layout_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBookingSheet(WidgetTester tester, Size viewport) async {
    final store = await LocalDataStore.openInMemory();
    store.bindPersistence();
    tester.view.physicalSize = Size(
      viewport.width * tester.view.devicePixelRatio,
      viewport.height * tester.view.devicePixelRatio,
    );
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAlmanacTheme(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => CreateBookingSessionSheet.show(
                      context,
                      initialDate: DateTime(2026, 9, 11),
                    ),
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('booking sheet lays out on 320×568 without overflow', (
    tester,
  ) async {
    await pumpBookingSheet(tester, const Size(320, 568));
    expect(find.text('Запись на время'), findsOneWidget);
    expect(find.text('Открыть запись'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Открыть запись')).bottom,
      lessThanOrEqualTo(568),
    );
  });

  testWidgets('booking sheet stays usable with keyboard insets', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await pumpBookingSheet(tester, const Size(390, 844));
    expect(find.text('Открыть запись'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking sheet stays above the android navigation bar', (
    tester,
  ) async {
    const bar = 48.0;
    final padding = logicalViewPadding(tester, bottom: bar);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(() {
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    await pumpBookingSheet(tester, const Size(390, 844));
    expect(find.text('Открыть запись'), findsOneWidget);
    expect(
      tester.getRect(find.text('Открыть запись')).bottom,
      lessThanOrEqualTo(844 - bar + 0.5),
    );
    expect(tester.takeException(), isNull);
  });
}
