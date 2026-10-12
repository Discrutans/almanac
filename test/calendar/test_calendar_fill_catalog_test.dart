import 'package:almanac/calendar/test_calendar_fill_catalog.dart';
import 'package:almanac/calendar/widgets/test_calendar_fill_catalog_list.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has unique ids and covers core groups', () {
    final ids = TestCalendarFillCatalog.all.map((f) => f.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(ids.length, greaterThanOrEqualTo(20));
    expect(ids, contains('recurrence_daily'));
    expect(ids, contains('conflict_shift'));
    expect(ids, contains('schedule_office'));
    expect(ids, contains('savings_overdue'));
    expect(ids, contains('today_checklist'));
    expect(ids, contains('stress_long_text'));
    for (final feature in TestCalendarFillCatalog.all) {
      expect(feature.placements, isNotEmpty, reason: feature.id);
    }
  });

  test('l10n resolves every catalog feature and placement', () {
    final l10n = AppLocalizations(const Locale('ru'));
    for (final feature in TestCalendarFillCatalog.all) {
      final title = l10n.testCalendarFillFeatureTitle(feature.id);
      expect(title, isNot(feature.id), reason: feature.id);
      for (final placement in feature.placements) {
        final label = l10n.testCalendarFillPlacementLabel(placement.name);
        expect(label, isNot(placement.name), reason: placement.name);
      }
    }
  });

  testWidgets('catalog list shows features and placements', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 600));
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
        theme: buildAlmanacTheme(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: TestCalendarFillCatalogList(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TestCalendarFillCatalogList), findsOneWidget);
    expect(find.text('Повтор · ежедневно'), findsOneWidget);
    expect(find.textContaining('Сегодня'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Конфликт со сменой'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Конфликт со сменой'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Заметки и чек-листы по месяцам'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Заметки и чек-листы по месяцам'), findsOneWidget);
  });
}
