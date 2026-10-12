# ТЗ: сервер и связь с данными (Almanac)

Версия: 2.0  
Дата: 16.09.2026  
Продукт: Almanac  
Статус: спецификация текущей реализации (as-is) и правила развития

Связанные документы: [architecture.md](../docs/architecture.md), [features.md](../docs/features.md), [platform-api.md](../docs/platform-api.md), [self-hosted.md](../docs/self-hosted.md), лаборатория [AlmanacHomeLab.md](../server/scripts/AlmanacHomeLab.md).

---

## 0. Что было в исходном ТЗ и почему оно не про Almanac

Файл раньше описывал **Sermo**: встроенный HTTP/WebSocket mini-server в том же процессе, что Flutter UI (`127.0.0.1:4780`, `x-sermo-token`, Sembast, прямой gRPC в YDB с устройства).

В Almanac этого контура **нет**:

| Sermo (старое ТЗ) | Almanac (факт) |
| --- | --- |
| Mini-server внутри приложения, порт 4780 | Отдельный процесс FastAPI (`server/`), порт **8080** |
| UI только через loopback HTTP | UI ходит в репозитории и Riverpod напрямую |
| Sembast + очередь сообщений | SQLite snapshot `almanac.db` |
| YDB с телефона (ключ SA на устройстве) | Тот же путь: `ydb_flutter_sdk` из приложения; таблица `almanac_snapshots`. Без домена и VPS |
| Мессенджер, E2EE нет, поля шифруются `dataKey` | Календарь; шифрования snapshot на сервере нет |
| Обязательный облачный sync | Сервер **опционален**; personal-профиль работает офлайн |

Нельзя «дотянуть» Sermo-mini-server в Almanac без смены продукта. Ниже — как устроено **это** приложение.

---

## 1. Назначение

Almanac — offline-first календарь. Источник правды для UI — **локальный snapshot** на устройстве.

Отдельный self-hosted API нужен только для:

- snapshot-sync календаря между устройствами с одним API key;
- сессий **записи** (`booking`) и **совместного планирования** (`collaborative`);
- блокировок события в collaborative-профиле;
- deep link `/join/:token` и живого WebSocket;
- домашней лаборатории (`ALMANAC_HOME_LAB=1`);
- **мини-сервера в приложении** (то же API без процесса Python).

Входа и регистрации нет. Клиент = локальный профиль + (если сеть) Server URL, `X-Api-Key`, `X-Profile-Id`.

```text
Flutter UI
    │  Riverpod / репозитории (без HTTP на localhost)
    ▼
LocalDataStore  ──persist──►  SQLite almanac.db
    │
    ├─ http / WebSocket  (если задан Server URL)  → FastAPI / мини-сервер
    └─ gRPC YDB          (если задан SA JSON)     → serverless Yandex YDB
                                                    домен не нужен
```

---

## 2. Зачем не встраивать mini-server в Flutter

| Требование Almanac | Как закрыто сейчас |
| --- | --- |
| Календарь без сети | CRUD в памяти + persist в SQLite, сервер не стартует |
| Телефон и ПК в одной сессии | API на LAN / WireGuard / VPS, не loopback телефона |
| Смена бэкенда | FastAPI: `ALMANAC_DB_BACKEND=sqlite\|ydb`; UI не меняется |
| Секреты облака | SA JSON для прямого YDB — в защищённом хранилище устройства (`flutter_secure_storage`). В `almanac_ydb.json` остаются только endpoint, путь к базе и workspace key. На FastAPI ключ остаётся на сервере |
| Живые слоты | WS `/v1/ws/sessions/:token` между клиентами (HTTP API). Прямой YDB синхронизирует только snapshot календаря |
| Простой контракт | REST `/v1/...` **или** YQL `almanac_snapshots`; виджеты не знают SQL/YQL |

Прямой gRPC из `lib/` в YDB **допускается** как бесплатный вариант без домена (лимиты serverless Yandex YDB). OAuth `y0_` отклоняется; нужен JSON авторизованного ключа SA.

Встроенный **мини-сервер** (`lib/platform/mini_server/`) — опция, не замена UI-репозиториям:

- UI календаря по-прежнему пишет в SQLite напрямую;
- процесс приложения может **раздать** тот же REST/WS контракт, что FastAPI (`/health`, `/v1/sessions`, snapshot, locks, `/join`);
- другие устройства в LAN указывают Server URL на этот телефон/ПК;
- Python не обязателен. Включается в «Ссылки и API». Слушает `0.0.0.0` (порт 8080, иначе 4780 или свободный).

Это не Sermo-loopback: виджеты не ходят на `127.0.0.1` для каждой правки события.

### 2.1. Бесплатно без домена: YDB с устройства

Если нет своего домена и VPS, календарь синхронизируется напрямую с **Yandex Serverless YDB** (`grpcs://ydb.serverless.yandexcloud.net:2135`):

1. Хозяин в «Ссылки и API» вставляет путь базы и `authorized_key.json` (роль `ydb.editor`).
2. Приложение создаёт таблицу `almanac_snapshots` и пишет snapshot по `(api_key, profile_id)`.
3. Гостю — строка `almanac-ydb:1:…` (в ней ключ SA). Домен не нужен; лимиты — квоты serverless YDB (`RESOURCE_EXHAUSTED` → подождать).
4. Сессии записи/планирования на этом пути **нет** — только snapshot календаря. Для живых слотов нужен FastAPI или мини-сервер с публичным URL.

Секрет не попадает в `almanac.db`. Веб-сборка YDB не поднимает (`dart:io`).

---

## 3. Состав при старте

Клиент (`lib/main.dart`):

1. `LocalDataStore.open()` — SQLite snapshot, in-memory репозитории.
2. `EventReminderService` — локальные уведомления.
3. `ProviderScope` → `AlmanacApp` → `PlatformBootstrap`.
4. Если задан Server URL: auto-sync snapshot, опрос pending, `POST /v1/devices/register`.

Сервер (`server/almanac/main.py`) — другой процесс:

| Модуль | Путь | Роль |
| --- | --- | --- |
| FastAPI app | `server/almanac/main.py` | REST, CORS, landing `/join` |
| Auth | `server/almanac/auth.py` | `X-Api-Key`, auto-provision workspace |
| SQLite repo | `server/almanac/db/repository.py` | сессии, snapshot, locks |
| YDB repo | `server/almanac/db/ydb_repository.py` | тот же контракт |
| Session WS | `server/almanac/ws/hub.py` | слоты, presence, booking_request |
| Lab | `server/almanac/routes/lab.py` | `/lab`, `/lab/plan` при `HOME_LAB` |

Клиент к API:

| Класс | Файл | Роль |
| --- | --- | --- |
| `LocalDataStore` | `lib/data/local/local_data_store.dart` | локальная правда UI |
| `AlmanacRemoteSyncService` | `lib/data/remote/almanac_remote_sync_service.dart` | push/pull snapshot |
| `RemoteAlmanacPlatformApi` | `lib/platform/remote_almanac_platform_api.dart` | сессии, workspace |
| `LocalAlmanacPlatformApi` | `lib/platform/almanac_platform_api.dart` | offline-шаблоны booking / group plan |
| `SessionWebSocketClient` | `lib/platform/session_websocket_client.dart` | realtime сессии |
| `EventLockService` | `lib/data/remote/event_lock_service.dart` | lock события, heartbeat 30 с, TTL 90 с |
| `RemoteAutoSyncScheduler` | `lib/data/remote/remote_auto_sync.dart` | debounce push ~2 с после persist |
| `MiniServerController` | `lib/platform/mini_server/` | LAN REST/WS в процессе приложения; «Ссылки и API» |

---

## 4. Транспорт и доступ

### 4.1. Где слушает API

- Хост по умолчанию `0.0.0.0`, порт **8080** (`ALMANAC_HOST` / `ALMANAC_PORT`).
- Origin для ссылок: `ALMANAC_PUBLIC_ORIGIN` / поле «Публичный URL» — **интернет-адрес** (HTTPS-домен). LAN IP только запасной вариант, если публичного URL нет.
- WebSocket: `ws(s)://…/v1/ws/sessions/:token?clientId=&name=&apiKey=`.

Это **не** loopback-only. Публичный VPS — нормальный режим.  
Исключение: страницы `/lab*` только с private/loopback IP и только при `ALMANAC_HOME_LAB=1`.

### 4.2. Аутентификация

| Заголовок | Смысл |
| --- | --- |
| `X-Api-Key` | идентификатор workspace; при первом запросе создаётся |
| `X-Profile-Id` | контекст профиля (`default` и др.) |

Нет логина. Кто знает ключ — владелец workspace.

Публично без ключа:

- `GET /health`
- `GET /v1/sessions/:token`
- `GET /join/:token` (landing сессии)
- `GET /connect` (landing гостя workspace, мини-сервер)
- WebSocket сессии (гость); патчи гостя ограничены `max_editors`

Остальное без ключа → 401.

Ключ хранится в `PlatformConfig` локального snapshot, не генерируется на каждый запуск процесса UI.

### 4.3. Формат

JSON, `Content-Type: application/json`. Ошибки FastAPI: `{ "detail": "…" }`.

---

## 5. REST-контракт (устройство ↔ FastAPI)

Базовый URL **без** `/v1`. Клиент дописывает путь (`lib/platform/server_url.dart`).

| Группа | Примеры | Куда пишет |
| --- | --- | --- |
| Health | `GET /health` | — |
| Workspace | `GET /v1/workspace` | строка workspace по ключу |
| Snapshot | `GET/POST /v1/calendar/snapshot` | JSON календаря workspace |
| Locks | `POST/DELETE /v1/calendar/locks/:eventId` | эксклюзивная правка события |
| Сессии | `POST/GET/DELETE /v1/sessions`, `GET /v1/sessions/:token` | слоты, форма, статус |
| Заявки | `PATCH /v1/sessions/:token/requests/:id` | confirm / reject |
| Устройства | `POST /v1/devices/register` | FCM token |
| Lab | `/lab`, `/lab/plan`, `/v1/lab/*` | только home-lab |
| Join | `GET /join/:token` | HTML → `almanac://join/…?server=` |
| Connect | `GET /connect?key=&profile=` | HTML → `almanac://connect?server=&key=` (гость workspace) |

Правило **локальной правки события**:

1. UI → `EventRepository` (память).
2. Snapshot dirty → persist SQLite.
3. Если Server URL и auto-sync — через ~2 с `POST /v1/calendar/snapshot` (не ждать ответа для отрисовки).
4. Конфликт: `resolveSyncDirection` по `updatedAt` (push / pull / upToDate).

История календаря для UI читается **из SQLite/памяти**, не live-запросом в FastAPI на кадр.

Сессии — другой путь: создание REST, состояние слотов — WebSocket, не snapshot.

---

## 6. Локальная БД (SQLite snapshot)

Назначение: источник правды UI и тело snapshot-sync.

`LocalDataStore` держит:

- профили (`personal` / `collaborative` / `booking`) и активный id;
- события, RRULE, вложения заметок, pomodoro, финансы;
- рабочие графики и override;
- цели накопления;
- локальные booking templates и group plans (offline);
- `PlatformConfig` (Server URL, API key, device id, auto push/pull);
- гостевые ICS, быстрые шаблоны, флаги подсказок, локаль.

Файл: `almanac.db` в каталоге приложения. Возможна миграция с legacy JSON.

Напоминания — отдельный локальный планировщик, не сервер.

---

## 7. Удалённая БД сервера

Контракт: `DatabaseRepository` (Python). Реализации: SQLite и YDB. Flutter **не** выбирает движок.

Хранится на сервере:

- workspaces (`api_key`, `profile_id`);
- calendar snapshot JSON + `updated_at`;
- event locks;
- sessions, clients, booking requests;
- device tokens для FCM.

Имя бэкенда: `ALMANAC_DB_BACKEND=sqlite` \| `ydb`. UI не ветвится по имени.

Шифрования полей календаря на пути в БД **нет**. HTTPS на VPS — ответственность хоста. Не обещать E2EE.

---

## 8. Синхронизация календаря

Включается, если в профиле (или `--dart-define=SERVER_URL`) задан origin **и** `ENABLE_REMOTE_SYNC` / UI-флаги позволяют sync.

| Событие | Действие |
| --- | --- |
| Persist после правки | debounce ~2 с → push snapshot |
| Resume приложения | pull; если remote новее — restore; иначе push если local новее |
| Ручные «Отправить / Загрузить» | тот же сервис |

Сравнение только по метке времени snapshot, не по-событийный merge и не CRDT.  
Collaborative-события дополнительно: short-lived lock (TTL 90 с, heartbeat 30 с); 409 если занято другим device id.

Inbox заявок: опрос ~10 с в `PlatformBootstrap` (+ локальные уведомления; FCM опционален).

---

## 9. Сессии и события в UI

`SessionWebSocketClient` на `ws://…/v1/ws/sessions/:token`:

- `state` — полное состояние при входе;
- `patch` / `patch_applied` — слоты (`addSlot`, `removeSlot`, `updateSlot`, `setSlots`);
- `presence` — участники;
- `booking_request*` — заявка и решение;
- `error` — лимит редакторов, слот занят, сессия не найдена.

Это канал **между клиентами через FastAPI**, не локальный fan-out.

Гость без `apiKey` в collaborative: лимит `state.settings.max_editors` (в приложении обычно 3). Владелец (`apiKey` = ключ workspace) — без лимита.

Календарный экран **не** подписан на этот WS: он живёт от локального snapshot.

Deep link: `https://origin/join/TOKEN` или `almanac://join/TOKEN?server=`. Гость без Server URL в профиле берёт origin из `server=`.

Гость **workspace** по HTTP: `http://host:port/connect?key=&profile=` или `almanac://connect?server=&key=&profile=`. Хозяин мини-сервера / FastAPI должен быть в сети.

Гость **workspace** по YDB (без домена): строка `almanac-ydb:1:…` или `almanac://ydb?p=`. В приглашении есть SA JSON — кто его получил, читает и пишет ту же serverless-базу. Сессии/WS на этом пути нет, только snapshot календаря.

---

## 10. Lifecycle

| Событие | Действие |
| --- | --- |
| Старт приложения | открыть SQLite; сервер не обязателен |
| Foreground | refresh pending, pull snapshot если настроен, high refresh rate |
| Persist | auto-push snapshot |
| Смена Server URL / ключа | следующие HTTP/WS идут на новый origin |
| Home lab | `AlmanacHomeLab.bat` → `/lab` и `/lab/plan` |
| Мини-сервер | «Ссылки и API» → bind `0.0.0.0`; гости `/connect` |

Смена профиля подключения не закрывает FastAPI: сервер живёт отдельно от приложения.  
Мини-сервер живёт **в процессе** приложения: пока хозяин держит «Включить мини-сервер», гости ходят на LAN URL этого устройства.

---

## 11. Требования к реализации (чеклист)

Обязательно:

1. Календарный UI только через репозитории / Riverpod, не через loopback HTTP.
2. Сеть — FastAPI **или** мини-сервер в приложении по Server URL; без URL приложение полностью работает.
3. Optimistic write в SQLite до ответа snapshot-sync.
4. Реализации БД сервера — `DatabaseRepository` (sqlite / ydb).
5. SA JSON для прямого YDB хранится в secure storage устройства (не в snapshot и не в plaintext `almanac_ydb.json`). HTTP-путь по-прежнему не кладёт облачный ключ в приложение.
6. Сессии и snapshot — разные контуры; не смешивать слоты WS в `eventsByProfile` без явного confirm booking.
7. `GET /v1/sessions/:token` публичный; патчи гостя ограничивать `max_editors`.
8. `/lab*` не включать на публичном VPS (`HOME_LAB` по умолчанию выкл.).
9. Ключ и `home_lab.json` не коммитить (`server/data/*.json` в gitignore).

Запрещено:

- встраивать mini-server / `shelf` в `lib/` как единственный доступ к данным;
- вызывать YDB из виджетов напрямую (только `YdbSnapshotClient` / sync service);
- считать API key паролем пользователя (это секрет workspace);
- обещать E2EE или по-событийный merge snapshot;
- биндить lab-эндпоинты в интернет;
- требовать логин/регистрацию.

---

## 12. Приёмка

1. Без Server URL: создать событие → оно в календаре и в SQLite; сеть не нужна.
2. Два устройства, один API key + Server URL: A правит событие → после auto-push / pull B видит snapshot (не мгновенный CRDT; секунды + метка `updatedAt`).
3. Collaborative: lock на правке; второе устройство получает 409, пока heartbeat жив.
4. Booking: владелец создаёт сессию → гость `/join` → заявка → confirm → событие у владельца.
5. Collaborative-сессия: два клиента на WS видят add/remove слота без перезагрузки (`/lab/plan` или два приложения).
6. Без `X-Api-Key` на `/v1/workspace` → 401; `GET /health` → `{"status":"ok"}`.
7. `AlmanacHomeLab.bat` → `/lab/plan` создаёт сессию и комнату WS с loopback.
8. Без домена: хозяин сохраняет YDB → гость вставляет ссылку на базу → после push/pull у гостя тот же snapshot. Live YDB в CI не гоняется.

---

## 13. Вне скоупа этого контура

- Встроенный HTTP mini-server в процессе Flutter как **единственный** доступ UI к данным (модель Sermo). Mini-server в `lib/platform/mini_server/` — опциональный LAN Platform API, не замена SQLite.
- По-событийный sync / CRDT вместо целого snapshot.
- Аккаунты, OAuth, разделение ключа и пользователя.
- Шифрование snapshot на сервере.
- Вынести realtime календаря на тот же WS, что сессии.
- Публичный lab (`/lab`) вне домашней сети.

---

## 14. Плюсы и минусы этой схемы

Оценка **текущей** реализации Almanac (локальный SQLite + опциональный FastAPI), не гипотетического mini-server в приложении.

### Плюсы

- **Офлайн по умолчанию.** Personal-календарь не зависит от Python, Docker и порта 8080. Падение сервера не гасит UI.
- **Сервер можно не ставить.** Совместность — осознанная опция, а не обязательная облачная база с ключом SA на телефоне.
- **Телефон и ПК в одной комнате.** API на LAN / WireGuard / VPS; гость открывает `/join` без loopback 127.0.0.1 чужого устройства.
- **Секреты YDB не на устройстве.** Смена sqlite↔ydb — `.env` сервера; Flutter не пересобирают.
- **Простой контракт.** Один origin, два заголовка, без логина. Удобно для лаборатории и self-host.
- **Два контура под разные задачи.** Snapshot — редкий обмен календарём; WS — живые слоты сессии. Не нужно гонять весь календарь на каждый клик слота.
- **Домашняя лаборатория.** `/lab/plan` проверяет планирование без ожидания сборки APK: браузер + телефон.
- **Нет лишнего HTTP на каждый кадр календаря.** Скролл месяца не ходит на localhost:4780, в отличие от схемы Sermo.

### Минусы

- **Нет единого in-process API.** Второй клиент (веб-календарь, бот) не может «просто ударить в 127.0.0.1 приложения»; нужен поднятый FastAPI. Локальные репозитории — Dart-only.
- **Snapshot грубый.** Конфликт — кто позже по `updatedAt`, не слияние событий. Два офлайн-редактора легко затирают друг друга.
- **Ключ = весь workspace.** Утечка API key даёт snapshot, сессии, locks. Auto-provision по любому ключу упрощает старт и усложняет отзыв доступа.
- **Токен сессии публичный.** Зная `/join/:token`, гость читает слоты. Это удобно, но не «закрытая комната».
- **Календарь не realtime.** Collaborative-события синкаются snapshot + lock, не WS. Участник не видит чужую правку за 200 мс, как слот в сессии.
- **Нет шифрования на сервере.** Хост SQLite/YDB видит JSON календаря. Для домашнего ПК приемлемо; для чужого VPS — доверие к хосту.
- **Две реализации платформы.** `LocalAlmanacPlatformApi` (offline templates) и `RemoteAlmanacPlatformApi` (живые сессии) легко разъехаться.
- **Сервер должен быть доступен с телефона.** NAT, firewall 8080, неверный IP `172.18.*` (Docker) — типичные сбои лаборатории. Mini-server на loopback этих проблем не имел бы, но и чужой телефон к нему не подключить.
- **Опрос inbox, не push по умолчанию.** Без FCM задержка до ~10 с. Booking не такой живой, как WS-слоты.
- **Процесс Python отдельно.** Нужны 3.11+, зависимости, порт. Для «только календарь на одном телефоне» это лишнее — поэтому сервер опционален, но для совместности это плата.

### Когда что выбирать

| Сценарий | Вывод |
| --- | --- |
| Один человек, один телефон | Сервер не нужен — плюсы схемы максимальные |
| Семья / смена в LAN, self-host | FastAPI + `/lab` — штатный путь; минус snapshot-конфликтов терпим |
| Много одновременных правок одного события | Слабое место; нужен был бы WS/CRDT, его нет |
| Мессенджер с YDB с устройства (Sermo) | **Не копировать** в Almanac: другой продукт и другие угрозы (SA на телефоне, loopback не fore phone) |

Итого: для календаря с опциональным совместным планированием текущая схема **плюс** относительно встроенного mini-server. **Минус** — грубый sync календаря и секретность ключа/токена. Развивать сервер как отдельный FastAPI; не переносить Sermo-loopback в `lib/`.
