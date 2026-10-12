import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/data/profiles/profile_kind.dart';
import 'package:almanac/profiles/create_profile_sheet.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalDataStore> pumpSheet(WidgetTester tester) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
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
                    onPressed: () => CreateProfileSheet.show(context),
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
    return store;
  }

  testWidgets('create profile starts with device, cloud and invite choices', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text('Только на этом устройстве'), findsOneWidget);
    expect(find.text('С облаком'), findsOneWidget);
    expect(find.text('Подключиться к профилю'), findsOneWidget);
    expect(find.text('Совместный'), findsNothing);
    expect(find.text('Profile ID владельца'), findsNothing);
  });

  testWidgets('personal path creates a local profile without server fields', (
    tester,
  ) async {
    final store = await pumpSheet(tester);
    await tester.tap(find.text('Только на этом устройстве'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Дом');
    await tester.tap(find.widgetWithText(FilledButton, 'Создать профиль'));
    await tester.pumpAndSettle();
    final created = store.profileRepository
        .getAll()
        .where((profile) => profile.name == 'Дом')
        .single;
    expect(created.kind, ProfileKind.personal);
    expect(created.role, ProfileRole.owner);
  });

  testWidgets('join path asks only for an invite paste', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('Подключиться к профилю'));
    await tester.pumpAndSettle();
    expect(find.text('Ссылка на базу YDB'), findsOneWidget);
    expect(find.text('URL сервера'), findsNothing);
    expect(find.text('API Key'), findsNothing);
    expect(find.text('Profile ID владельца'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Подключиться'));
    await tester.pumpAndSettle();
    expect(find.textContaining('не ссылка Almanac'), findsOneWidget);
  });
}
