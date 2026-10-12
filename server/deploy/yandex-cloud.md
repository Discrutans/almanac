# Deploy Almanac API on Yandex Cloud

**Полная пошаговая инструкция (RU):** [yandex-cloud-full.md](yandex-cloud-full.md)  
**Docker (сборка, VM, Container Registry):** [yandex-docker.md](yandex-docker.md)  
**Готовый env:** [.env.yandex.example](.env.yandex.example)  
**Docker Compose:** [../docker-compose.yandex.yml](../docker-compose.yandex.yml)

## Components

1. **YandexDB** — production database (`server/almanac/db/schema.yql`)
2. **Serverless Containers or Compute VM** — FastAPI + WebSocket (long-lived process required)
3. **Application Load Balancer** — TLS termination and WSS passthrough
4. **Object Storage + CDN** — static landing at `/join/{token}`

## Local YDB stack

```bash
cd server
docker compose up --build
```

This starts:
- `ydb-local` on port `2136`
- `almanac-api` with `ALMANAC_DB_BACKEND=ydb`

SQLite-only stack:

```bash
docker compose -f docker-compose.sqlite.yml up --build
```

Apply schema manually (if needed):

```bash
cd server
ALMANAC_DB_BACKEND=ydb ALMANAC_YDB_ENDPOINT=grpc://localhost:2136 ALMANAC_YDB_DATABASE=/local \
  python scripts/apply_ydb_schema.py
```

## Build image for Yandex Container Registry

```bash
cd server
docker build -t cr.yandex/<registry-id>/almanac-api:latest .
docker push cr.yandex/<registry-id>/almanac-api:latest
```

## Container environment

| Variable | Example |
|----------|---------|
| `ALMANAC_PUBLIC_ORIGIN` | `https://calendar.example.com` |
| `ALMANAC_DB_BACKEND` | `ydb` |
| `ALMANAC_YDB_ENDPOINT` | `grpcs://ydb.serverless.yandexcloud.net:2135` |
| `ALMANAC_YDB_DATABASE` | `/ru-central1/.../etn...` |
| `ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE` | `/secrets/key.json` |
| `ALMANAC_FCM_SERVER_KEY` | Firebase legacy server key (optional) |

## Push notifications

1. Register device token from Flutter:

```
POST /v1/devices/register
X-Api-Key: ...
{"token": "<fcm-token>", "platform": "android"}
```

2. Set `ALMANAC_FCM_SERVER_KEY` on the server.
3. On new booking request the server sends FCM + WS broadcast.

## WebSocket note

Do **not** deploy the API to Cloud Functions. Use Serverless Containers or a VM.

## Flutter production

```bash
flutter build apk \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=SERVER_URL=https://api.example.com \
  --dart-define=ENABLE_REMOTE_SYNC=true \
  --dart-define=PUBLIC_ORIGIN=https://api.example.com
```

Update Android App Links host in `android/app/src/main/AndroidManifest.xml` and iOS Associated Domains to match your public domain.
