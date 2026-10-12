import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';

void main() {
  test('AppLocaleNotifier persists language to LocalDataStore', () async {
    final store = await LocalDataStore.openInMemory();
    final container = ProviderContainer(
      overrides: [localDataStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider).languageCode, 'ru');

    container.read(appLocaleProvider.notifier).setLanguageCode('en');

    expect(container.read(appLocaleProvider).languageCode, 'en');
    expect(store.localeLanguageCode, 'en');

    final snapshot = store.exportSnapshot();
    expect(snapshot.localeLanguageCode, 'en');
  });

  test('AppLocaleNotifier restores language from store snapshot', () async {
    final store = await LocalDataStore.openInMemory();
    store.applyLocale('en');

    final container = ProviderContainer(
      overrides: [localDataStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appLocaleProvider).languageCode, 'en');
  });
}
