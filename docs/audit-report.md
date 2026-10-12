# Audit Almanac — документация и продукт

**Дата:** 2026-10-01  
**Метод:** сверка `docs/` и [README.md](../README.md) с `lib/`, `server/`, `test/calendar`.

Полный обзор для людей: [project-guide.md](project-guide.md).  
Оглавление docs: [README.md](README.md).

---

## 1. Инвентаризация документации

| Файл | Уникальный контент | Дублирует | Риск устаревания |
|------|-------------------|-----------|------------------|
| project-guide.md | Обзор UI, маршруты, функции | architecture §профили, features (сжато) | Низкий после сверки |
| architecture.md | Поток данных, дерево repo | README структура, infoDB | Средний (sync timing) |
| features.md | Таблицы функций + пути модулей | project-guide | Средний (week DnD, sync) |
| week-ui.md | Z-order, carousel/wide spec | project-guide §4 | Средний (historical audit) |
| platform-api.md | REST/WS контракт | infoDB, self-hosted | Низкий при редких API changes |
| self-hosted.md | Deploy | README server block | Низкий |
| app-links.md | AASA, assetlinks | deep_link.dart | Средний (connect URI) |
| infoDB.md | Кратко data+API | platform-api | Низкий |
| perf-scroll.md | Hz, cache | settings high_refresh_rate | Низкий |
| qa-checklist.md | Ручные шаги | features сценарии | Средний (sync/inbox timing) |

**Server-only markdown** (не в `docs/`): `server/scripts/AlmanacHomeLab.md`, `server/deploy/*.md` — деплой Yandex; ссылка из [self-hosted.md](self-hosted.md).

---

## 2. Drift: документ ↔ код

| Тема | Было в docs | Факт в коде | Статус |
|------|-------------|-------------|--------|
| Auto-sync после правки | architecture ~5 с debounce; qa-checklist ~5 с | `PlatformBootstrap._scheduleAutoSync` → `RemoteAutoSyncScheduler.schedulePush()` **без delay** (`Duration.zero`); нужны `ENABLE_REMOTE_SYNC`, `enableAutoRemoteSync`, `config.autoPush` | **Исправлено** в architecture, qa-checklist |
| Inbox / pending poll | features ~45 с | `_pendingPollInterval = Duration(seconds: 10)` | **Исправлено** в features |
| Week event move | features → `week_carousel_unified`; week-ui LongPressDraggable gaps | `WeekMoveController`, `WeekTimedDragLayer`, `WeekHoldMoveRecognizer`; unified **и** `week_events_drop_grid` | **Исправлено** в features, week-ui banner |
| Deep links | features `almanac://join` | + `almanac://connect`, HTTPS `/connect`, `parseYdbInvite` | **Исправлено** в features §11 |
| Debounce persist | architecture «debounce persist» | SQLite persist через LocalDataStore; push сразу после persist | Уточнено в architecture |

---

## 3. Карта UI surfaces (клиент)

### Full screen

| Surface | Файл | Назначение |
|---------|------|------------|
| CalendarScreen | `lib/calendar/calendar_screen.dart` | Hub: 4 режима, create bar, toolbar |
| SessionPage | `lib/sessions/session_page.dart` | Booking / collaborative по token |

### Overlays (sheets / dialogs)

| Surface | Файл | Перегрузка |
|---------|------|------------|
| SettingsSheet | `lib/profiles/settings_sheet.dart` | 4/5 — профиль + sync + calendar prefs |
| PlatformLinksSheet | `lib/profiles/platform_links_sheet.dart` | 5/5 — YDB + API + mini-server + sessions list |
| CreateEntryPickerSheet | `lib/calendar/widgets/chrome/create_entry_picker_sheet.dart` | 3/5 |
| DayDateActionsSheet | `lib/calendar/widgets/chrome/day_date_actions_sheet.dart` | Дубли 3 kind из picker |
| DayEventsSheet | `lib/calendar/widgets/chrome/day_events_sheet.dart` | День + create |
| EventPreviewSheet | `lib/calendar/widgets/chrome/event_preview_sheet.dart` | View + inline edit |
| CreateEventDialog | `lib/calendar/widgets/forms/create_event_dialog.dart` | Create entry |
| PendingBookingsSheet | inbox via toolbar | Remote + legacy panels |
| WorkScheduleSheet, SavingsGoalsSheet | schedules/, finance/ | Create side paths |
| CreateBooking/Collab/Join session sheets | `lib/sessions/session_creation/` | Server sessions |

### Orchestration

| Компонент | Строки (approx) | Проблема |
|-----------|-----------------|----------|
| `calendar_screen_actions.dart` (part) | ~966 | CRUD, booking, YDB, navigation, create — **кандидат на CalendarFlowController** |

---

## 4. Пользовательские сценарии — дубли и серые зоны

| Сценарий | Входы сегодня | Проблема |
|----------|---------------|----------|
| Создать event/note/checklist | «+» picker; DayActions; DayEvents→picker; month **без** нижнего «+» | Разный набор опций |
| Booking member | «+»→`_bookExistingSession`; DayActions book | Много обёрток, hint в picker |
| Create session (owner) | Только CreateEntryPicker | Нет в PlatformLinks (только list/close) |
| Edit event | Preview; `_editEvent*` ×3 в mixin | Один UI, несколько API |
| Month long-press | → week view | ≠ long-press в других режимах → DayActions |
| Manage sessions | PlatformLinks list | Не связано с create funnel |

**Рекомендация (Part B UX):** CreateHub + CreateActionPolicy; Workspace sheet — отдельный план UI/UX rework (не в scope этого audit).

---

## 5. Legacy и параллельные пути

| Путь | Назначение | Рекомендация |
|------|------------|--------------|
| Remote session + inbox | Production booking | Оставить, primary |
| `LegacyLocalPendingPanel` | Offline booking templates | Показывать только если `!hasRemote && local pending` (уже так) |
| YDB offers + `BookingOfferFormSheet` | Booking без FastAPI | Отдельный UX-copy от «сессии REST»; не смешивать в одном пункте меню |
| Mini-server on device | LAN API | Power-user; оставить в PlatformLinks |

---

## 6. Backend snapshot (для docs)

Корень: `server/almanac/`. Основные группы маршрутов:

| Prefix | Модуль | Назначение |
|--------|--------|------------|
| `/v1/calendar` | `routes/calendar.py` | snapshot GET/POST, locks |
| `/v1/sessions` | `routes/sessions.py`, `booking.py` | CRUD sessions, patch requests |
| `/v1/ws/sessions/{token}` | `ws/hub.py` | WebSocket |
| `/v1/workspace` | `routes/workspace.py` | Workspace probe |
| `/v1/devices` | `routes/devices.py` | Push register |
| `/join/{token}` | `main.py` | Landing |
| `/lab`, `/v1/lab/*` | `routes/lab.py` | Home lab |

Детали: [platform-api.md](platform-api.md), [self-hosted.md](self-hosted.md).

---

## 7. Данные на клиенте

| Слой | Файлы |
|------|--------|
| Snapshot | `lib/data/local/local_data_store.dart` |
| Events | `lib/data/events/` repositories |
| Profiles | `lib/data/profiles/` |
| Remote sync | `lib/data/remote/remote_sync_service.dart`, `remote_auto_sync.dart` |
| Platform config | `lib/platform/platform_config_repository.dart` |

Кратко: [infoDB.md](infoDB.md), [architecture.md](architecture.md).

---

## 8. Следующие шаги

1. ~~Hub `docs/README.md`~~ — готово.
2. ~~Точечные правки architecture, features, week-ui, qa~~ — см. коммит.
3. **UX rework** — после стабилизации docs: CreateHub, Workspace, flow controller (отдельный plan).
4. Периодически обновлять §2 и дату в project-guide §11.
