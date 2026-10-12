import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/forms/create_event_dialog.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/core/ui/almanac_buttons.dart';
import 'package:almanac/data/local/local_data_store.dart';
import 'package:almanac/state/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

Widget _app({required Widget home, List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
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
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create form warns on overlap but still allows save', (
    tester,
  ) async {
    final store = await LocalDataStore.openInMemory(seedDemoData: false);
    store.bindPersistence();
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final existing = AppEvent(
      id: 'busy',
      dateTimeRange: DateTimeRange(
        start: DateTime(2026, 9, 18, 10),
        end: DateTime(2026, 9, 18, 11),
      ),
      title: 'Busy',
      startTime: '10:00',
      endTime: '11:00',
      color: Colors.orange,
    );

    AppEvent? saved;
    await tester.pumpWidget(
      _app(
        overrides: [localDataStoreProvider.overrideWithValue(store)],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CreateEventDialog(
              date: DateTime(2026, 9, 18),
              existingEvents: [existing],
              onPersist: (event) async {
                saved = event;
              },
              initialStartTime: const TimeOfDay(hour: 10, minute: 30),
              initialEndTime: const TimeOfDay(hour: 11, minute: 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Это время пересекается с другим событием'),
      findsOneWidget,
    );
    expect(
      find.text('Конфликт: время пересекается с другим событием'),
      findsNothing,
    );

    final titleFields = tester.widgetList<TextField>(find.byType(TextField));
    final titleField = titleFields.firstWhere(
      (field) => field.controller?.text.isEmpty ?? true,
      orElse: () => titleFields.first,
    );
    await tester.enterText(find.byWidget(titleField), 'Overlap ok');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AlmanacAsyncFilledButton));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, 'Overlap ok');
    expect(saved!.startTime, '10:30');
  });
}
