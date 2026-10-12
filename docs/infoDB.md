# Almanac Platform — данные и API

Клиентская архитектура и реестр функций: [architecture.md](architecture.md), [features.md](features.md).

## Self-hosted (текущая архитектура)

**Один универсальный URL API** для любого хостинга:

```
https://your-server.example/v1/...
```

Подробнее: [self-hosted.md](self-hosted.md)

| Слой | Технология |
|------|------------|
| Backend | Python FastAPI + WebSocket |
| БД (dev) | SQLite |
| БД (prod) | YandexDB или SQLite на VPS |
| Клиент | Flutter + `RemoteAlmanacPlatformApi` |
| Auth | `X-Api-Key` + `X-Profile-Id` |

## Публичные ссылки

| Тип | URL | Назначение |
|-----|-----|------------|
| Сессия (новое) | `/join/:token` → приложение `/session/:token` | Планирование или запись |
| Legacy запись | `/book/:token` | редирект на `/session/:token` |
| Legacy план | `/plan/:token` | редирект на `/session/:token` |

## UI в приложении

**Профили → «Ссылки и API»**:

- **Server URL** — адрес вашего API (любой хостинг)
- **API Key**, **Profile ID** — для REST и синхронизации
- **Совместное планирование (сессия)** / **Запись на время (сессия)**
- Deep link копируется автоматически

## API

Документация: [platform-api.md](platform-api.md)  
Схема YDB: [server/almanac/db/schema.yql](../server/almanac/db/schema.yql)  
Пример env: [server/.env.example](../server/.env.example)

## Локальные данные

Календарь и настройки профиля: SQLite `almanac.db` на устройстве (миграция из legacy `almanac_data.json` при первом запуске).  
При `ENABLE_REMOTE_SYNC=true` или Server URL в профиле — snapshot на сервер (`POST /v1/calendar/snapshot`).  
Фоновый push после изменений: debounce 5 с (см. [self-hosted.md](self-hosted.md)).

## Развёртывание

```bash
cd server
docker compose up --build          # YDB local + API
# или
docker compose -f docker-compose.sqlite.yml up --build
```

Yandex Cloud: [server/deploy/yandex-cloud.md](../server/deploy/yandex-cloud.md)
