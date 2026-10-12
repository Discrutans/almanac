# Almanac Platform API v2

Self-hosted REST + WebSocket API. **Один базовый URL** — развёртывание на любом хостинге.

> Полное руководство: **[self-hosted.md](self-hosted.md)**

## Connection

| Header | Description |
|--------|-------------|
| `X-Api-Key` | Workspace API key from the app (Platform Links) |
| `X-Profile-Id` | Context profile id (`default`, …) |
| `Content-Type` | `application/json` |

**Server URL** (единый для всего):

```
https://your-server.example
```

Не добавляйте `/v1` в URL — клиент допишет путь сам.

Public deep link:

```
https://your-server.example/join/:token
```

Custom scheme:

```
almanac://join/:token
```

## REST

### Workspace

```
GET /v1/workspace
```

### Sessions

```
POST /v1/sessions
{
  "mode": "collaborative",
  "title": "Team schedule",
  "slots": [
    {"id": "...", "start": "2026-06-26T10:00:00", "end": "2026-06-26T11:00:00"}
  ],
  "form_fields": [{"id": "...", "label": "ФИО", "required": true}],
  "profile_id": "default"
}
```

```
GET /v1/sessions
GET /v1/sessions/:token
DELETE /v1/sessions/:token
PATCH /v1/sessions/:token/requests/:id  {"status": "confirmed"}
```

### Calendar snapshot

```
GET /v1/calendar/snapshot
POST /v1/calendar/snapshot  {"profile_id": "default", "snapshot": {...}}
```

## WebSocket

```
wss://your-server.example/v1/ws/sessions/:token?clientId=...&name=Guest
```

Messages:

- `state` — full session on join
- `patch` — collaborative edits (`baseVersion`, `ops`)
- `booking_request` — guest submits booking
- `booking_request_created` / `booking_request_decided` — owner/guest updates

## Local development

```bash
cd server
pip install -r requirements.txt
uvicorn almanac.main:app --reload --port 8080
```

Or:

```bash
docker compose up --build
```

Flutter:

```bash
flutter run \
  --dart-define=SERVER_URL=http://10.0.2.2:8080 \
  --dart-define=ENABLE_REMOTE_SYNC=true \
  --dart-define=PUBLIC_ORIGIN=http://10.0.2.2:8080
```

## Deploy anywhere

| Host | Guide |
|------|-------|
| Any VPS / Docker | [self-hosted.md](self-hosted.md) |
| Yandex Cloud | [server/deploy/yandex-cloud.md](../server/deploy/yandex-cloud.md) |

```bash
cd server
cp .env.example .env
docker compose -f docker-compose.sqlite.yml up --build
```
