import 'package:almanac/app/app.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calendar shell lays out at 360 width without overflow', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory();
    store.bindPersistence();

    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: const AlmanacApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Месяц'), findsOneWidget);
    expect(find.text('Неделя'), findsOneWidget);

    // Switch modes that historically stress narrow toolbars.
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Список'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
