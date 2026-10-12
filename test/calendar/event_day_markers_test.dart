import 'package:almanac/calendar/calendar_types.dart';
import 'package:almanac/calendar/widgets/chrome/event_day_markers.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AppEvent _event(int index) {
  return AppEvent(
    id: 'e$index',
    dateTimeRange: DateTimeRange(
      start: DateTime(2026, 9, 9, 10 + index),
      end: DateTime(2026, 9, 9, 11 + index),
    ),
    title: 'Event $index',
    startTime: '10:00',
    endTime: '11:00',
    color: Colors.teal,
  );
}

void main() {
  test('month dots leave room for overflow label', () {
    final band = eventDayMarkersBandHeight(
      compact: false,
      style: EventDayMarkerStyle.dots,
    );
    expect(band, greaterThanOrEqualTo(eventDotMarkerSize(compact: false)));
    expect(
      band,
      greaterThanOrEqualTo(eventDotOverflowFontSize(compact: false)),
    );
    expect(eventDotMarkerSize(compact: false), greaterThanOrEqualTo(8));
  });

  testWidgets('dot markers show how many extra events remain', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAlmanacTheme(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: Scaffold(
          body: Center(
            child: EventDayMarkers(
              events: List.generate(7, _event),
              maxVisible: 3,
              style: EventDayMarkerStyle.dots,
              showOverflowCount: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('+4'), findsOneWidget);
    expect(find.text('+'), findsNothing);
  });

  testWidgets('dot markers hide overflow when everything fits', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAlmanacTheme(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: Scaffold(
          body: Center(
            child: EventDayMarkers(
              events: List.generate(3, _event),
              maxVisible: 3,
              style: EventDayMarkerStyle.dots,
              showOverflowCount: true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('+'), findsNothing);
  });
}
