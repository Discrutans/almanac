# UX rework — baseline (pre-change)

**Дата:** 2026-10-01  
**План:** UI/UX rework (CreateHub, Workspace, EventOpenPolicy, week DnD polish).

---

## 1. Journey maps (4 персоны)

### Personal owner
1. Открыть календарь → неделя → tap слот → «+» → picker (8 пунктов) → event dialog.
2. Hold-drag событие → preview contour → drop → persist.
3. Tap событие → preview (week) / mixed paths (agenda).
4. Month tap день → DayEventsSheet (cover) → create footer.

### Booking owner
1. Toolbar inbox → pending → confirm.
2. «+» → booking session (в picker) — нет shortcut из Workspace до rework.
3. PlatformLinks в Settings → sessions list.

### Booking member (`canBookOnly`)
1. Create bar «Запись» → book flow.
2. Inbox hidden; preview on slots with book action.

### Collaborative member
1. «+» → collab session (tier 2 после rework).
2. Locked events → read-only preview.

---

## 2. Матрица: режим × tap × surface (target after rework)

| Режим | Tap день | Tap событие | Hold drag | Create |
|-------|----------|-------------|-----------|--------|
| Month | DayEventsSheet | via day sheet → Preview | — | footer + **create bar (post-1)** |
| Week | select slot/date | **Preview** | **Move (DnD)** | bar + CreateHub |
| Agenda | select | **Preview** | — | bar + CreateHub |
| Year | month pick | — | — | optional bar (post-1) |

---

## 3. Week DnD acceptance (regression gate)

| # | Сценарий | Wide | Carousel |
|---|----------|------|----------|
| W1 | Hold timed event → preview follows finger | ✓ | ✓ |
| W2 | Drop on valid slot → commit, time updates | ✓ | ✓ |
| W3 | Cancel drag → no persist | ✓ | ✓ |
| W4 | Resize handle → duration changes | ✓ | ✓ |
| W5 | Locked / booking slot not draggable | manual | manual |
| W6 | hideEmpty expand → drop target valid | manual | manual |
| W7 | Short tap → preview, not drag | post-4b | post-4b |

Automated: `flutter test test/calendar` (WeekMoveController, recognizer, drag layer).

---

## 4. Baseline QA smoke (ручной)

- [x] Create from week bar + from month day sheet — same hub options (post-1).
- [x] Settings → Workspace entry (post-3), no full server block in Settings.
- [x] Inbox REST vs legacy sections labeled (post-5).
- [x] Agenda row tap → preview only (post-4b).

---

## 5. Phase log

| Phase | Status | Notes |
|-------|--------|-------|
| 0 | done | this file |
| 1 | done | CreateHub, month bar |
| 2 | done | CalendarFlowController |
| 3 | done | WorkspaceSheet |
| 4–4c | done | DayActions, preview, slot label |
| 5 | done | Inbox facade |
| 6 | done | qa + project-guide |
