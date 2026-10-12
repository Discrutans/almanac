# Week UI — audit, architecture, spec

> Timed-перенос и preview: `WeekTimedDragLayer` + `WeekHoldMoveRecognizer` + `WeekMoveController`. Сверка: [project-guide §11](project-guide.md#11-актуальность-документации).

Недельный вид Almanac: **wide (7 дней)** и **carousel (3 дня)**.  
Визуальный язык: квадратные ячейки часа + `WeekEventCellContourPainter`.  
Документ закрывает фазы A–C плана week UI/UX.

## Audit (фаза A)

### Карта модулей

```
week_view.dart
  ├─ week_layout.dart          — compact vs carousel, hint banner
  ├─ week_carousel_panel.dart  — обёртка WeekCarouselUnified
  ├─ week_carousel_sync.dart   — select/snap/DnD hit-test/autoscroll
  └─ week_events_panel.dart    — WeekEventsDropGrid (wide)
widgets/week/
  ├─ week_carousel_unified.dart — strip + shared vertical scroll + lanes
  ├─ week_events_drop_grid.dart — 7-col timed scroll + overlays
  ├─ week_day_column.dart       — tiles, slot, armed, preview, resize
  ├─ week_hour_grid.dart        — lines, labels, now-line
  ├─ week_hour_axis.dart        — segments, hideEmpty, pin helpers
  ├─ week_selection_frame.dart  — slot / armed / preview frame
  ├─ week_drag_policy.dart      — delays, lock, armed
  ├─ week_move_controller.dart  — start/update/commit preview
  ├─ week_drop_hit_test.dart    — drop targets, preview model
  └─ week_ui_tokens.dart        — shared opacities / scroll layer
```

### Дубли carousel ↔ wide (до унификации)

| Кусок | Carousel | Wide |
|-------|----------|------|
| Vertical timed scroll | `_timedScroll` (один) | `_timedScroll` |
| Labels overlay | Transform + bottom align | то же |
| Now-line | per-column `showNowLine` (default) | overlay, columns `showNowLine: false` |
| Pin apply | `weekAxisApplyPinPostFrame` | то же |
| Monolithic grid | да | да |
| Drop preview | `WeekSelectionFrame` primary | то же |
| Ghost lanes | opacity 0.38 | N/A (только выбранная неделя) |

### Gap-list (закрыто / остаток)

1. Now-line: единый overlay + `showNowLine: false` на колонках — закрыто.
2. Preview ≈ slot → разные alpha/border (`WeekUiTokens`) — закрыто; preview ≥ 0.15 для читаемости на hideEmpty Y-drag.
3. Magic numbers ghost/dragging → `WeekUiTokens` — закрыто.
4. Labels overlay → `WeekTimedScrollLayer` — закрыто.
5. Nested timed scroll vs long-press drag (primaryDelta spam, нет preview) — **закрыто:** `WeekTimedDragLayer`, hold-move recognizer, lock scroll при expand/drag + resize без primaryDelta.
6. hideEmpty expand → post-frame refresh drop target (carousel + wide) — закрыто.

## Architecture (фаза B)

### Общее

- `WeekHourAxis` — геометрия часа / hideEmpty.
- `WeekAxisViewportPin` + `weekAxisApplyPinPostFrame` — владение pin.
- `WeekUiTokens` + `WeekTimedScrollLayer` — визуал и scroll-sync overlays.
- `WeekDayColumn` — единый timed stack (z-order ниже).
- `WeekMoveController` — один preview/commit pipeline (carousel + wide).
- `WeekDragSession` / `week_drop_hit_test` — armed/lock policy и hit-test.

### Режим-специфично

- **Carousel:** sticky strip + horizontal sync strip↔timed; ghost lanes; week-shift autoscroll; `itemExtent` paging.
- **Wide:** 7 `Expanded` columns; now-line left = `index * colWidth`; no ghost.

### Z-order (оба режима)

`grid → emptyHit → allDayPad → tiles → now → dropPreview → armed → selectedSlot`  
(+ hour labels gutter overlay поверх viewport, IgnorePointer).

### Scroll ownership

- Carousel timed: один `_timedScroll`; horizontal days: parent `controller`; strip: `_stripScroll` synced.
- Wide timed: `_timedScroll`; no horizontal day scroll.

## Spec — каталог функций

| # | Функция | Carousel | Wide | Приёмка |
|---|---------|----------|------|---------|
| 1 | Select / snap / center / today | да | select only | Центр выбранного дня стабилен |
| 2 | Sticky strip | да | N/A (month/week chrome иначе) | Strip не уезжает с часами |
| 3 | Ghost days | да | N/A | Opacity `ghostOpacity`, drop ok |
| 4 | Monolithic grid | да | да | Без стыков колонок |
| 5 | Labels + live | да | да | Live только на labels |
| 6 | Now-line | overlay | overlay | Только сегодня, sync scroll |
| 7 | hideEmpty + pin | да | да | Expand/collapse без улёта фокуса |
| 8 | Pinch zoom | да | да | Labels scale, pin держит минуты |
| 9 | Timed tiles + cascade | да | да | Contour = cell; пороги из tokens |
| 10 | All-day in pad | да | да | Не ломает timed hit-test |
| 11 | Empty → slot | да | да | 1h slot + axis expand |
| 12 | Slot + handles | да | да | Сильнее preview |
| 13 | Resize event | да | да | Live labels, commit/cancel |
| 14 | Armed / lock | да | да | Delays из policy |
| 15 | Drag + preview | да | да | Preview слабее slot |
| 16 | Slot drag | да | да | Тот же preview pipeline |
| 17 | Autoscroll | V+H | V | Края двигают сетку |
| 18 | Overlap warn | да | да | Warn, не блок timed |
| 19 | Drag hint | да | да | Dismissible banner |
| 20 | Color / foreign | да | да | Opacity/marker из profile visual |

### Состояния рамки

| Роль | fill α | border | handles |
|------|--------|--------|---------|
| Drop preview | `previewFillAlpha` | `previewBorderWidth` | нет |
| Armed | `armedFillAlpha` | `armedBorderWidth` | да |
| Selected slot | `slotFillAlpha` | `slotBorderWidth` | да |

### Токены

См. [`week_ui_tokens.dart`](../lib/calendar/widgets/week/week_ui_tokens.dart).
