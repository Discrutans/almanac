import 'package:almanac/calendar/calendar_event_index.dart';
import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/date_cell.dart';
import 'package:almanac/calendar/widgets/week/week_carousel_snap_physics.dart';
import 'package:almanac/calendar/widgets/week/week_carousel_unified.dart';
import 'package:almanac/calendar/widgets/week/week_day_column.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _timed({
  required String id,
  required DateTime day,
  required int startHour,
  required int endHour,
}) {
  return AppEvent(
    id: id,
    dateTimeRange: DateTimeRange(
      start: DateTime(day.year, day.month, day.day, startHour),
      end: DateTime(day.year, day.month, day.day, endHour),
    ),
    title: id,
    startTime: '${startHour.toString().padLeft(2, '0')}:00',
    endTime: '${endHour.toString().padLeft(2, '0')}:00',
    color: Colors.teal,
  );
}

void main() {
  testWidgets(
    'carousel uses one vertical timed scroll for all visible days',
    (tester) async {
      const viewportWidth = 360.0;
      const height = 520.0;
      final columnWidth = DateCellLayout.weekCarouselColumnWidth(viewportWidth);
      final selected = DateTime(2026, 6, 17);
      final laneDates = weekCarouselWindowDates(
        windowStart: weekCarouselWindowStartFor(selected),
      );
      final eventsIndex = <DateTime, List<AppEvent>>{
        for (final date in laneDates)
          calendarDayKey(date): [
            _timed(
              id: 'early-${date.day}',
              day: date,
              startHour: 0,
              endHour: 1,
            ),
            _timed(
              id: 'late-${date.day}',
              day: date,
              startHour: 22,
              endHour: 23,
            ),
          ],
      };
      final horizontal = ScrollController();
      final viewportKey = GlobalKey<WeekCarouselUnifiedState>();
      addTearDown(horizontal.dispose);

      await tester.binding.setSurfaceSize(const Size(viewportWidth, height));
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
            body: SizedBox(
              width: viewportWidth,
              height: height,
              child: WeekCarouselUnified(
                key: viewportKey,
                height: height,
                columnWidth: columnWidth,
                viewportWidth: viewportWidth,
                laneDates: laneDates,
                selectedDate: selected,
                eventsIndex: eventsIndex,
                activeProfileId: 'default',
                onDateSelected: (_) {},
                onEditEvent: (_) {},
                controller: horizontal,
                hideEmptyWeekHours: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = viewportKey.currentState!;
      expect(state.verticalOffset, 0);

      final verticalViews = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .where((view) => view.scrollDirection == Axis.vertical)
          .toList();
      expect(verticalViews, hasLength(1));

      final dayColumns = tester.widgetList<WeekDayColumn>(
        find.byType(WeekDayColumn),
      );
      expect(dayColumns.length, greaterThanOrEqualTo(3));
      expect(
        dayColumns.every((column) => column.scrollTimedGrid == false),
        isTrue,
      );
      expect(
        dayColumns.every((column) => column.showNowLine == false),
        isTrue,
      );
      expect(
        dayColumns.every((column) => column.paintHourLines == false),
        isTrue,
      );

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();

      expect(state.verticalOffset, greaterThan(50));
      expect(verticalViews.single.controller!.offset, state.verticalOffset);
    },
  );

  testWidgets('carousel horizontal strip stays synced with timed days', (
    tester,
  ) async {
    const viewportWidth = 360.0;
    const height = 520.0;
    final columnWidth = DateCellLayout.weekCarouselColumnWidth(viewportWidth);
    final selected = DateTime(2026, 6, 17);
    final laneDates = weekCarouselWindowDates(
      windowStart: weekCarouselWindowStartFor(selected),
    );
    final horizontal = ScrollController();
    addTearDown(horizontal.dispose);

    await tester.binding.setSurfaceSize(const Size(viewportWidth, height));
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
          body: SizedBox(
            width: viewportWidth,
            height: height,
            child: WeekCarouselUnified(
              height: height,
              columnWidth: columnWidth,
              viewportWidth: viewportWidth,
              laneDates: laneDates,
              selectedDate: selected,
              eventsIndex: const {},
              activeProfileId: 'default',
              onDateSelected: (_) {},
              onEditEvent: (_) {},
              controller: horizontal,
              hideEmptyWeekHours: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = columnWidth * 3;
    horizontal.jumpTo(target);
    await tester.pumpAndSettle();

    final horizontals = tester
        .widgetList<ListView>(find.byType(ListView))
        .where((view) => view.scrollDirection == Axis.horizontal)
        .where((view) => view.controller != null && view.controller!.hasClients)
        .toList();
    expect(horizontals.length, greaterThanOrEqualTo(2));
    for (final view in horizontals) {
      expect(view.controller!.offset, closeTo(target, 1));
    }
  });
}
