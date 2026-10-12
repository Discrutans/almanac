import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/ui/almanac_scroll.dart';
import 'package:almanac/core/ui/almanac_sheets.dart';
import 'package:almanac/platform/high_refresh_rate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HighRefreshRate.configure enables pointer resampling', () async {
    await HighRefreshRate.configure();
    expect(GestureBinding.instance.resamplingEnabled, isTrue);
  });

  test('AlmanacScrollBehavior accepts mouse, trackpad and stylus', () {
    const behavior = AlmanacScrollBehavior();
    expect(
      behavior.dragDevices,
      containsAll({
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      }),
    );
  });

  test('week carousel prefetch grows with column width', () {
    expect(
      weekCarouselCacheExtent(80),
      80 * AlmanacScroll.carouselPrefetchColumns,
    );
    expect(weekCarouselCacheExtent(0), AlmanacScroll.listCacheExtent);
  });

  testWidgets('sheet content stays scrollable after a dismiss drag', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        scrollBehavior: const AlmanacScrollBehavior(),
        home: const MediaQuery(
          data: MediaQueryData(size: Size(400, 800)),
          child: _ScrollSheetHarness(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Scroll panel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final handle = find.byType(AlmanacPanelDragHandle);
    expect(handle, findsOneWidget);
    await tester.drag(handle, const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('row 0'), findsOneWidget);

    await tester.drag(find.text('row 0'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _ScrollSheetHarness extends StatelessWidget {
  const _ScrollSheetHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            showAlmanacSheet<void>(
              context: context,
              title: 'Scroll panel',
              child: Column(
                children: [
                  for (var i = 0; i < 24; i++)
                    SizedBox(height: 48, child: Text('row $i')),
                ],
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}
