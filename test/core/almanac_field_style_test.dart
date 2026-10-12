import 'package:almanac/core/theme/almanac_theme.dart';
import 'package:almanac/core/theme/almanac_tokens.dart';
import 'package:almanac/core/ui/almanac_segmented_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThemeData theme() =>
      buildAlmanacTheme(seedColor: Colors.blue, brightness: Brightness.dark);

  test('highlights and fields share rounded input styling', () {
    final data = theme();
    final enabled =
        data.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    final focused =
        data.inputDecorationTheme.focusedBorder as OutlineInputBorder;
    final listShape = data.listTileTheme.shape as RoundedRectangleBorder;
    final sheetShape = data.bottomSheetTheme.shape as RoundedRectangleBorder;
    final dialogShape = data.dialogTheme.shape as RoundedRectangleBorder;

    expect(enabled.borderRadius, AlmanacRadius.input);
    expect(focused.borderRadius, AlmanacRadius.input);
    expect(
      data.inputDecorationTheme.contentPadding,
      AlmanacFieldLayout.contentPadding,
    );
    expect(data.inputDecorationTheme.isDense, isFalse);
    expect(listShape.borderRadius, AlmanacFieldLayout.highlightRadius);
    expect(sheetShape.borderRadius, AlmanacRadius.sheetTop);
    expect(
      dialogShape.borderRadius,
      BorderRadius.circular(AlmanacRadius.sheet),
    );
  });

  testWidgets('text field and dropdown share height in the same form row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(decoration: InputDecoration(labelText: 'Name')),
                SizedBox(height: 8),
                _TestDropdown(),
                SizedBox(height: 8),
                AlmanacSegmentedBar<int>(
                  values: [0, 1],
                  selected: 0,
                  onChanged: _noop,
                  labelOf: _labelOf,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final fieldHeight = tester.getSize(find.byType(TextField)).height;
    final dropdownHeight = tester.getSize(find.byType(_TestDropdown)).height;
    final barSize = tester.getSize(find.byType(AlmanacSegmentedBar<int>));

    expect((fieldHeight - dropdownHeight).abs(), lessThan(1));
    expect(barSize.height, AlmanacFieldLayout.height);
    expect(barSize.width, tester.getSize(find.byType(TextField)).width);
  });

  testWidgets('segment labels sit on the vertical center of the bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme(),
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: AlmanacSegmentedBar<int>(
                values: [0, 1],
                selected: 0,
                onChanged: _noop,
                labelOf: _labelOf,
              ),
            ),
          ),
        ),
      ),
    );

    final bar = tester.getRect(find.byType(AlmanacSegmentedBar<int>));
    final label = tester.getRect(find.text('One'));
    expect((label.center.dy - bar.center.dy).abs(), lessThan(1.5));
  });
}

void _noop(int value) {}

String _labelOf(int value) => value == 0 ? 'One' : 'Two';

class _TestDropdown extends StatelessWidget {
  const _TestDropdown();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: 1,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Profile'),
      items: const [DropdownMenuItem(value: 1, child: Text('Work'))],
      onChanged: (_) {},
    );
  }
}
