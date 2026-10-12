import 'package:almanac/calendar/event_display_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compactPreviewText skips bracket headers', () {
    const raw =
        '[Заметка · день 251 · 360 симв.]\nНужно купить хлеб и молоко для ужина';
    expect(compactPreviewText(raw), 'Нужно купить хлеб и молоко для ужина');
  });

  test('compactPreviewText trims long text on a word boundary', () {
    final preview = compactPreviewText(
      'alpha beta gamma delta epsilon',
      maxChars: 18,
    );
    expect(preview, 'alpha beta gamma…');
  });

  test('compactEventTitle strips character-count suffix', () {
    expect(compactEventTitle('Событие · 9.9 · 360 симв.'), 'Событие · 9.9');
  });

  test('compactEventTitle keeps ordinary titles', () {
    expect(compactEventTitle('Встреча с заказчиком'), 'Встреча с заказчиком');
  });
}
