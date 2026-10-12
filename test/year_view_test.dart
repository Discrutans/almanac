import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:almanac/app/app.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';

void main() {
  testWidgets('year view renders without layout errors', (tester) async {
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

    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('202'), findsWidgets);
  });
}
