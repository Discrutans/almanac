import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/core/ui/almanac_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('success snack is compact floating with short duration', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAlmanacTheme(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () =>
                    AlmanacFeedback.showSuccess(context, 'Сохранено'),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.behavior, SnackBarBehavior.floating);
    expect(snack.duration, const Duration(seconds: 2));
    expect(snack.shape, isA<RoundedRectangleBorder>());
    expect(find.text('Сохранено'), findsOneWidget);
  });

  testWidgets('error snack stays longer than success', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAlmanacTheme(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => AlmanacFeedback.showError(context, 'Ошибка'),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.duration, const Duration(milliseconds: 3500));
  });
}
