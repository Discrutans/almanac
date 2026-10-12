import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/schedule_quick_actions_bar.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart';

AppEvent _shiftEvent() {
  return AppEvent(
    id: 'schedule-demo-${DateTime(2026, 9, 9).millisecondsSinceEpoch}',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 9, 8),
      end: DateTime(2026, 9, 9, 17),
    ),
    title: 'Смена',
    startTime: '08:00',
    endTime: '17:00',
    color: Colors.blue,
    seriesId: 'schedule-demo',
    explicitEntrySource: CalendarEntrySource.scheduleGenerated,
    interaction: EventInteraction.allowNone(),
  );
}

void main() {
  testWidgets('shift actions stack vertically so labels fit a week column', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: ScheduleQuickActionsBar(
                event: _shiftEvent(),
                dense: true,
                onAction: (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final skip = tester.getRect(find.text('Пропуск'));
    final overtime = tester.getRect(find.text('+30 мин'));
    expect(overtime.top, greaterThan(skip.bottom - 0.5));
    expect(skip.width, lessThanOrEqualTo(120));
    expect(overtime.width, lessThanOrEqualTo(120));
  });
}
