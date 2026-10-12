# План: скролл и UI под 90/120/144 Гц+

Цель: панели, модалки и календарь не пропускают кадры на высоких герцовках.  
Физика Flutter уже привязана к vsync (время, не «кадры»). Узкие места — лишняя работа **на каждый указатель**: `setState`, `Opacity` (saveLayer), `Clip.antiAlias`, маленький `cacheExtent`, отсутствие ресемплинга жестов.

## Этап 1. Платформа и глобальный скролл

- Ресемплинг указателя к vsync (`GestureBinding.resamplingEnabled`).
- `AlmanacScrollBehavior`: мышь, тачпад, стилус; bounce на iOS/macOS, clamp на Android/desktop; stretch-overscroll только на Android.
- Prefetch: `AlmanacScroll.listCacheExtent` / `calendarCacheExtent`.
- Android: максимальный display mode + `setFrameRate` + отключение power-savings 120→60 (API 35).
- iOS: `CADisableMinimumFrameDurationOnPhone` (уже было) + канал герцовки.
- macOS: канал `NSScreen.maximumFramesPerSecond`.
- Engine `Display.refreshRate` для лога.

## Этап 2. Панели и модалки

- Свайп закрытия: `ValueNotifier` + `Transform.translate`, **без** `setState` и `Opacity` на всём дереве.
- `Clip.hardEdge` вместо `antiAlias` на оболочке.
- `RepaintBoundary` вокруг контента формы.
- Тело панели наследует физику `ScrollConfiguration`, а не жёсткий `ClampingScrollPhysics`.

## Этап 3. Календарь

- Неделя: prefetch 8 колонок, `RepaintBoundary` у ghost-дней, `cacheExtent` колонки.
- Agenda / год: больший `cacheExtent`, границы перерисовки у карточек месяца.
- Месяц: `RepaintBoundary` на строку недели.
- Панель событий дня и статистика месяца — общий prefetch.

## Этап 4. Остальной UI

- Сессия, создание collaborative-сессии, шаблоны, color picker — `cacheExtent` + dismiss клавиатуры по драгу.
- Вложенные `NeverScrollableScrollPhysics` списки (профили, графики, цели) остаются внутри скролла панели.

## Этап 5. Проверка

- `test/core/almanac_scroll_test.dart`
- layout / sheet / week carousel тесты

Код: `lib/core/ui/almanac_scroll.dart`, `lib/platform/high_refresh_rate.dart`.
