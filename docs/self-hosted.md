# Self-hosted: универсальный URL API

Almanac Platform — **один базовый URL** для любого хостинга.  
Не привязан к Yandex, Supabase или конкретному облаку.

## Модель подключения

```
https://ВАШ-ДОМЕН          ← единственный Server URL
├── GET  /health
├── GET  /v1/workspace          (X-Api-Key)
├── POST /v1/sessions           (X-Api-Key)
├── GET  /v1/sessions/:token    (публично)
├── POST /v1/calendar/snapshot  (X-Api-Key)
├── WS   /v1/ws/sessions/:token (real-time)
└── GET  /join/:token           (landing → deep link)
```

| Параметр | Где задаётся | Пример |
|----------|--------------|--------|
| **Server URL** | Приложение → «Ссылки и API» или `--dart-define=SERVER_URL` | `https://calendar.example.com` |
| **API Key** | Генерируется в приложении (UUID) | `a1b2c3d4-…` |
| **Profile ID** | Профиль контекста | `default` |

Deep link для участников:

```
https://ВАШ-ДОМЕН/join/TOKEN
almanac://join/TOKEN
```

## Куда можно развернуть

| Площадка | Как |
|----------|-----|
| **Свой VPS** (Linux) | Docker + [nginx.conf.example](../server/deploy/nginx.conf.example) + TLS |
| **Домашний сервер** | `docker compose -f docker-compose.sqlite.yml up` |
| **Yandex Cloud** | [server/deploy/yandex-cloud-full.md](../server/deploy/yandex-cloud-full.md) · Docker: [yandex-docker.md](../server/deploy/yandex-docker.md) |
| **Railway / Render / Fly.io** | Docker image + env vars |
| **Локально** | `uvicorn almanac.main:app --port 8080` |

БД на выбор:
- **SQLite** — проще всего (один файл)
- **YandexDB** — prod на Yandex (`ALMANAC_DB_BACKEND=ydb`)
- Любой VPS + SQLite достаточен для малой нагрузки

## Быстрый старт (Docker)

```bash
cd server
cp .env.example .env
# отредактируйте ALMANAC_PUBLIC_ORIGIN

docker compose -f docker-compose.sqlite.yml up --build
```

**Без Docker (Windows / локальная разработка):**

```powershell
cd server
pip install -r requirements.txt
.\scripts\run_sqlite.ps1
```

Или вручную:

```powershell
$env:ALMANAC_DB_BACKEND="sqlite"
$env:ALMANAC_SQLITE_PATH=".\data\almanac.db"
$env:ALMANAC_PUBLIC_ORIGIN="http://localhost:8080"
python -m uvicorn almanac.main:app --host 0.0.0.0 --port 8080 --reload
```

API: `http://localhost:8080`  
Проверка: `curl http://localhost:8080/health`

## Подключение Flutter

**Вариант A — в приложении (рекомендуется):**

1. Профили → **Ссылки и API**
2. **URL сервера** → `https://api.example.com`
3. Скопируйте **API Key**
4. Создайте сессию → получите deep link

**Вариант B — при сборке:**

```bash
flutter run \
  --dart-define=SERVER_URL=https://api.example.com \
  --dart-define=ENABLE_REMOTE_SYNC=true
```

`PUBLIC_ORIGIN` можно не указывать — если пустой, берётся тот же URL, что и Server URL.

## Подключение стороннего клиента

```bash
curl -H "X-Api-Key: YOUR-KEY" -H "X-Profile-Id: default" \
  https://api.example.com/v1/workspace
```

Полный контракт: [platform-api.md](platform-api.md)

## TLS и WebSocket

- REST: `https://…`
- WebSocket: `wss://…/v1/ws/sessions/:token`
- Reverse proxy: [nginx.conf.example](../server/deploy/nginx.conf.example) (Upgrade для WS)

## App Links (Android / iOS)

Сервер отдаёт verification files с того же `ALMANAC_PUBLIC_ORIGIN`:

- `GET /.well-known/apple-app-site-association`
- `GET /.well-known/assetlinks.json` (нужен `ALMANAC_ANDROID_SHA256_CERT`)

В `.env`:

```env
ALMANAC_ANDROID_PACKAGE=com.example.almanac
ALMANAC_ANDROID_SHA256_CERT=AA:BB:...
ALMANAC_IOS_TEAM_ID=ABCDE12345
ALMANAC_IOS_BUNDLE_ID=com.example.almanac
```

Android: задайте хост в `android/gradle.properties`:

```properties
ALMANAC_DEEP_LINK_HOST=api.example.com
```

iOS: замените `YOUR_DOMAIN` в `ios/Runner/Runner.entitlements` и подключите файл в Xcode.  
Подробнее: [app-links.md](app-links.md).

## Guest deep links

HTTPS landing `/join/:token` открывает приложение с параметром `server`:

```
almanac://join/TOKEN?server=https%3A%2F%2Fapi.example.com
```

Гость **без** Server URL в профиле подключается к серверу из ссылки автоматически.

## Auto-sync календаря

При настроенном Server URL snapshot отправляется на сервер через **5 секунд** после локальных изменений.  
Отключить: `--dart-define=ENABLE_AUTO_REMOTE_SYNC=false`

## Push-уведомления (FCM, optional)

Без Firebase приложение всё равно показывает локальные уведомления при polling pending-заявок (интервал **~10 с** на клиенте, см. `PlatformBootstrap`).

Для push через FCM:

1. **Сервер:** задайте `ALMANAC_FCM_SERVER_KEY` в `.env` (Firebase legacy server key).
2. **Клиент:** укажите FCM registration token одним из способов:
   - «Ссылки и API» → **Push-токен (FCM)**
   - `--dart-define=PUSH_DEVICE_TOKEN=…` при сборке
3. При старте приложение регистрирует токен через `POST /v1/devices/register`.

При новой booking-заявке сервер шлёт FCM всем зарегистрированным устройствам workspace + WS broadcast.

## Домашняя лаборатория

На ПК помощник включается флагом `ALMANAC_HOME_LAB=1` и отвечает **только** с loopback / частных IP.

Запуск Windows: `server/scripts/AlmanacHomeLab.bat` (или `.\scripts\run_home_lab.ps1`).  
Пошагово, рядом с батником: [AlmanacHomeLab.md](../server/scripts/AlmanacHomeLab.md).

| Страница | Назначение |
|----------|------------|
| `http://127.0.0.1:8080/lab` | Server URL, проверка `/health`, скрипты WireGuard для MikroTik |
| `http://127.0.0.1:8080/lab/plan` | Тест совместного планирования: сессия, ссылки `/join` и `almanac://`, живая комната WebSocket |

Сценарий: создать сессию → скопировать `/join` в Almanac на телефоне или открыть гостевую вкладку → добавлять и удалять слоты. Гость без API key ограничен `max_editors`; владелец (галочка + ключ) — нет.

Ключ лаборатории пишется в `home_lab.json` рядом с SQLite (не коммитьте файл).

## Что не нужно

- Отдельный Supabase / Firebase для Platform API
- Разные URL для booking и planning — всё через `/v1/sessions`
- Проприетарный SDK — достаточно HTTP + WebSocket + `X-Api-Key`
