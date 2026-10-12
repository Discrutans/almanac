# Almanac — self-hosted platform (актуальный чеклист)

Архитектура: **Flutter + Python FastAPI + SQLite/YDB**. Supabase удалён.  
Реестр функций: [docs/features.md](docs/features.md). Описание слоёв: [docs/architecture.md](docs/architecture.md).

## Backend

- [x] FastAPI REST + WebSocket (`/v1/sessions`, `/v1/ws/sessions/:token`)
- [x] SQLite (dev) + YDB repository (prod)
- [x] Calendar snapshot sync (`POST /v1/calendar/snapshot`)
- [x] Device registration (`POST /v1/devices/register`)
- [x] FCM stub on new booking request
- [x] Auto-provision workspace on first API key
- [x] App Links: `/.well-known/apple-app-site-association`, `/.well-known/assetlinks.json`
- [x] Docker compose (SQLite + YDB local)
- [x] nginx example (`server/deploy/nginx.conf.example`)

## Flutter client

- [x] `RemoteAlmanacPlatformApi` + Server URL в профиле
- [x] Session UI (collaborative + booking) + WebSocket sync
- [x] Deep links: `https://domain/join/:token`, `almanac://join/:token?server=`
- [x] Guest server origin from HTTPS deep link
- [x] Pending inbox (remote vs local)
- [x] Auto-sync snapshot on local persist (debounced)
- [x] Platform bootstrap: verify workspace, device id registration, poll pending 45s
- [x] iOS Associated Domains — `Runner.entitlements` подключён в Xcode project
- [x] Подтверждение booking → событие в календаре (inbox + session page)
- [x] Закрытие сессии владельцем (кнопка ✕ в AppBar)
- [x] Pending provider без setState во время build
- [x] Collaborative: редактирование слотов только у владельца
- [x] Имя гостя в сессии + закрытие сессии из «Ссылки и API»
- [x] `/book/:token` — local template или server session (умный роутинг)
- [x] Collaborative patches на сервере только с API key владельца
- [x] Push token в профиле + перерегистрация при смене Server URL
- [x] FCM: `--dart-define=PUSH_DEVICE_TOKEN=` или поле в «Ссылки и API»

## Legacy (local-only, без сервера)

- [x] `/book/:token` и `/plan/:token` — умный роутинг (local vs server)
- [x] Local booking templates + group plans (offline)
- [x] Legacy UI скрыт когда настроен Server URL
- [x] Inbox: server pending + legacy local при миграции

## Документация

- [self-hosted.md](docs/self-hosted.md)
- [platform-api.md](docs/platform-api.md)
- [infoDB.md](docs/infoDB.md)
- [qa-checklist.md](docs/qa-checklist.md)
- [app-links.md](docs/app-links.md)

## Manual QA

См. [qa-checklist.md](docs/qa-checklist.md) — чеклист + команды автотестов.

## Завершено (ранее «отложено»)

- [x] SQLite snapshot (`almanac.db` via `LocalSnapshotStore`, миграция из `almanac_data.json`)
- [x] Legacy local booking/group plan UI удалён — только server sessions
- [x] Production App Links: docs + Android `/plan` + server AASA paths
