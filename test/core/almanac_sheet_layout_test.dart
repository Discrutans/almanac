import 'package:almanac/core/localization/app_localizations.dart';
import 'package:almanac/core/ui/almanac_buttons.dart';
import 'package:almanac/core/ui/almanac_form_panel.dart';
import 'package:almanac/core/ui/almanac_sheets.dart';
import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/almanac_layout_harness.dart';

void main() {
  testWidgets('confirm sheet hugs content and stays compact on desktop', (
    tester,
  ) async {
    const viewport = Size(1280, 800);
    await tester.binding.setSurfaceSize(viewport);
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
        home: const MediaQuery(
          data: MediaQueryData(size: viewport),
          child: _ConfirmHarness(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final title = find.text('Delete item');
    expect(title, findsOneWidget);

    final panel = find
        .ancestor(of: title, matching: find.byType(Material))
        .first;
    final size = tester.getSize(panel);
    expect(
      size.width,
      lessThanOrEqualTo(AlmanacPanelLayout.compactMaxWidth + 1),
    );
    expect(size.height, lessThan(viewport.height * 0.5));
    expect(tester.getTopLeft(panel).dy, greaterThan(viewport.height * 0.4));
  });

  testWidgets('form actions stay pinned on a 360x780 sheet', (tester) async {
    const viewport = Size(360, 780);
    await tester.binding.setSurfaceSize(viewport);
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
        home: const MediaQuery(
          data: MediaQueryData(size: viewport),
          child: _FormHarness(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final save = find.text('Сохранить');
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(viewport.height));
    expect(tester.getRect(save).top, greaterThan(viewport.height * 0.45));
  });

  testWidgets('form actions stay above a 48px android bar', (tester) async {
    const viewport = Size(360, 780);
    const bar = 48.0;
    final padding = logicalViewPadding(tester, bottom: bar);
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    tester.view.physicalSize = Size(
      viewport.width * tester.view.devicePixelRatio,
      viewport.height * tester.view.devicePixelRatio,
    );
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() {
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.view.resetPhysicalSize();
      tester.binding.setSurfaceSize(null);
    });

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
        home: const _FormHarness(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    final save = find.text('Сохранить');
    expect(save, findsOneWidget);
    expect(
      tester.getRect(save).bottom,
      lessThanOrEqualTo(viewport.height - bar + 0.5),
    );
  });

  testWidgets('prompt can close without disposing the text controller early', (
    tester,
  ) async {
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
        home: const _PromptHarness(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Work'), findsNothing);
  });
}

class _PromptHarness extends StatelessWidget {
  const _PromptHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            showAlmanacPrompt(
              context: context,
              title: 'Rename profile',
              label: 'Name',
              confirmLabel: 'Save',
              cancelLabel: 'Cancel',
              initialValue: 'Profile',
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _ConfirmHarness extends StatelessWidget {
  const _ConfirmHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            showAlmanacConfirm(
              context: context,
              title: 'Delete item',
              message: 'This cannot be undone.',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _FormHarness extends StatelessWidget {
  const _FormHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () {
            showAlmanacSheet<void>(
              context: context,
              title: 'Создать событие',
              child: const _WrappedCreateForm(),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

/// Как [CreateEventDialog]: оболочка, внутри которой [AlmanacFormPanel].
class _WrappedCreateForm extends StatelessWidget {
  const _WrappedCreateForm();

  @override
  Widget build(BuildContext context) {
    return AlmanacFormPanel(
      body: const SizedBox(height: 900, child: Text('form body')),
      actions: AlmanacDialogActions(
        children: [
          TextButton(onPressed: () {}, child: const Text('Отмена')),
          FilledButton(onPressed: () {}, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
