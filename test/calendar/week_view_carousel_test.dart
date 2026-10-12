import 'package:almanac/calendar/views/week_view.dart';
import 'package:almanac/calendar/widgets/chrome/date_cell.dart';
import 'package:almanac/calendar/widgets/week/week_carousel_snap_physics.dart';
import 'package:almanac/calendar/widgets/week/week_carousel_unified.dart';
import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

double _carouselOffset(WidgetTester tester) {
  final horizontals = tester
      .widgetList<ListView>(find.byType(ListView))
      .where((view) => view.scrollDirection == Axis.horizontal)
      .where((view) => view.controller != null && view.controller!.hasClients)
      .toList();
  expect(horizontals, isNotEmpty);
  final offsets = [
    for (final view in horizontals) view.controller!.offset,
  ];
  // Sticky strip and timed days share one horizontal offset.
  for (final offset in offsets.skip(1)) {
    expect(offset, closeTo(offsets.first, 1));
  }
  return offsets.first;
}

void main() {
  testWidgets(
    'week carousel centers selected date on mount when scrollToTodayNonce > 0',
    (tester) async {
      const viewportWidth = 360.0;
      final columnWidth = DateCellLayout.weekCarouselColumnWidth(viewportWidth);
      final selectedDate = DateTime(2026, 6, 17);
      final focusedMonth = DateTime(2026, 6, 1);
      final displayDates = weekCarouselWindowDates(
        windowStart: weekCarouselWindowStartFor(selectedDate),
      );
      final selectedIndex = displayDates.indexWhere(
        (date) =>
            date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day,
      );

      expect(selectedIndex, greaterThan(0));

      await tester.binding.setSurfaceSize(const Size(viewportWidth, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
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
            home: MediaQuery(
              data: const MediaQueryData(size: Size(viewportWidth, 700)),
              child: SizedBox(
                width: viewportWidth,
                height: 700,
                child: WeekCalendarView(
                  focusedMonth: focusedMonth,
                  selectedDate: selectedDate,
                  scrollToTodayNonce: 3,
                  events: const [],
                  activeProfileId: 'default',
                  onDateSelected: (_) {},
                  onEditEvent: (_) {},
                  onDeleteEvent: (_) async => true,
                  onCreateEvent: () {},
                  onEventUpdated: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeekCarouselUnified), findsOneWidget);

      final offset = _carouselOffset(tester);
      final expected = weekCarouselScrollOffsetForDayIndex(
        dayIndex: selectedIndex,
        columnWidth: columnWidth,
      );

      expect(offset, closeTo(expected, 1));
    },
  );

  testWidgets('tapping a neighboring day centers it in the carousel', (
    tester,
  ) async {
    const viewportWidth = 360.0;
    final columnWidth = DateCellLayout.weekCarouselColumnWidth(viewportWidth);
    final focusedMonth = DateTime(2026, 6, 1);
    var selectedDate = DateTime(2026, 6, 17);
    final displayDates = weekCarouselWindowDates(
      windowStart: weekCarouselWindowStartFor(selectedDate),
    );

    int indexOf(DateTime date) => displayDates.indexWhere(
      (day) =>
          day.year == date.year &&
          day.month == date.month &&
          day.day == date.day,
    );

    await tester.binding.setSurfaceSize(const Size(viewportWidth, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
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
          home: MediaQuery(
            data: const MediaQueryData(size: Size(viewportWidth, 700)),
            child: SizedBox(
              width: viewportWidth,
              height: 700,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WeekCalendarView(
                    focusedMonth: focusedMonth,
                    selectedDate: selectedDate,
                    events: const [],
                    activeProfileId: 'default',
                    onDateSelected: (date) {
                      setState(() => selectedDate = date);
                    },
                    onSelectedDateInWeekChanged: (date) {
                      setState(() => selectedDate = date);
                    },
                    onEditEvent: (_) {},
                    onDeleteEvent: (_) async => true,
                    onCreateEvent: () {},
                    onEventUpdated: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final neighbor = DateTime(2026, 6, 18);
    await tester.tap(
      find.byKey(ValueKey('carousel-strip-${neighbor.toIso8601String()}')),
    );
    await tester.pumpAndSettle();

    expect(selectedDate, neighbor);

    expect(
      _carouselOffset(tester),
      closeTo(
        weekCarouselScrollOffsetForDayIndex(
          dayIndex: indexOf(neighbor),
          columnWidth: columnWidth,
        ),
        1,
      ),
    );
  });

  testWidgets('scroll snap selects the middle of the three visible days', (
    tester,
  ) async {
    const viewportWidth = 360.0;
    final columnWidth = DateCellLayout.weekCarouselColumnWidth(viewportWidth);
    final focusedMonth = DateTime(2026, 6, 1);
    var selectedDate = DateTime(2026, 6, 17);
    final displayDates = weekCarouselWindowDates(
      windowStart: weekCarouselWindowStartFor(selectedDate),
    );
    final startIndex = displayDates.indexWhere(
      (day) =>
          day.year == selectedDate.year &&
          day.month == selectedDate.month &&
          day.day == selectedDate.day,
    );

    await tester.binding.setSurfaceSize(const Size(viewportWidth, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
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
          home: MediaQuery(
            data: const MediaQueryData(size: Size(viewportWidth, 700)),
            child: SizedBox(
              width: viewportWidth,
              height: 700,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return WeekCalendarView(
                    focusedMonth: focusedMonth,
                    selectedDate: selectedDate,
                    events: const [],
                    activeProfileId: 'default',
                    onDateSelected: (date) {
                      setState(() => selectedDate = date);
                    },
                    onSelectedDateInWeekChanged: (date) {
                      setState(() => selectedDate = date);
                    },
                    onEditEvent: (_) {},
                    onDeleteEvent: (_) async => true,
                    onCreateEvent: () {},
                    onEventUpdated: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(WeekCarouselUnified),
      Offset(-columnWidth, 0),
    );
    await tester.pumpAndSettle();

    expect(selectedDate, DateTime(2026, 6, 18));

    expect(
      _carouselOffset(tester),
      closeTo(
        weekCarouselScrollOffsetForDayIndex(
          dayIndex: startIndex + 1,
          columnWidth: columnWidth,
        ),
        1,
      ),
    );
  });
}
