import 'package:almanac/app/app.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalDataStore> pumpEmptyApp(WidgetTester tester) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    tester.view.physicalSize = Size(
      360 * tester.view.devicePixelRatio,
      780 * tester.view.devicePixelRatio,
    );
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        child: const AlmanacApp(),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('empty calendar week view stays interactive', (tester) async {
    await pumpEmptyApp(tester);

    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();

    expect(find.text('Добавить'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creating an event requires a title then persists the entry', (
    tester,
  ) async {
    final store = await pumpEmptyApp(tester);

    await tester.tap(find.text('2').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Событие').first);
    await tester.pumpAndSettle();

    expect(find.text('Название'), findsWidgets);

    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Введите название события'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Проверка сценария');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Введите название события'), findsNothing);
    expect(
      store.eventRepository
          .getMasterEvents(profileId: 'default')
          .any((event) => event.title == 'Проверка сценария'),
      isTrue,
    );
  });
}
