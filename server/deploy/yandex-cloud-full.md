# Almanac на Yandex Cloud + YandexDB

**Доступ к вашей БД ассистенту давать не нужно и небезопасно.**  
Достаточно выполнить шаги ниже у себя в консоли Yandex Cloud и на VM/контейнере.

---

## Архитектура

```
Flutter app  ──HTTPS/WSS──►  VM или Serverless Container  ──gRPCs──►  YandexDB
                              (FastAPI :8080)                        (сессии, sync)
                              ▲
                         ALB + TLS (ваш домен)
```

- **Не используйте Cloud Functions** — нужен long-lived WebSocket.
- **SQLite** — только для локальной разработки; prod = **YandexDB**.

---

## Шаг 1. YandexDB

### Вариант A — Serverless YDB (проще для старта)

1. [Консоль Yandex Cloud](https://console.cloud.yandex.ru/) → **YandexDB** → **Serverless**.
2. Создайте базу в `ru-central1`.
3. Запишите:
   - **Endpoint:** `grpcs://ydb.serverless.yandexcloud.net:2135`
   - **Database path:** `/ru-central1/b1g.../etn...` (из карточки БД)

### Вариант B — Dedicated YDB

Создайте кластер YDB, endpoint вида `grpcs://ydb.<id>.yandexcloud.net:2135`.

---

## Шаг 2. Сервисный аккаунт

1. **IAM** → **Сервисные аккаунты** → создать, например `almanac-api`.
2. Роли на **каталог** (folder), где лежит YDB:
   - `ydb.editor` (или минимум права на вашу БД)
3. **Создать ключ** → JSON → сохранить как `server/secrets/sa-key.json`  
   **Не коммить в git.** Добавьте в `.gitignore` при необходимости.

---

## Шаг 3. Конфигурация API

```powershell
cd server
copy deploy\.env.yandex.example .env.yandex
# отредактируйте .env.yandex — endpoint, database path, PUBLIC_ORIGIN
mkdir secrets
# скопируйте sa-key.json в secrets\
```

Пример `.env.yandex`:

```env
ALMANAC_PUBLIC_ORIGIN=https://api.your-domain.ru
ALMANAC_DB_BACKEND=ydb
ALMANAC_YDB_ENDPOINT=grpcs://ydb.serverless.yandexcloud.net:2135
ALMANAC_YDB_DATABASE=/ru-central1/b1gxxxxxxxx/etnxxxxxxxx
ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE=/secrets/sa-key.json
ALMANAC_CORS_ORIGINS=*
```

---

## Шаг 4. Схема таблиц в YDB

**Один раз** примените схему из репозитория:

```powershell
cd server
pip install -r requirements.txt

# загрузить переменные из .env.yandex (PowerShell):
Get-Content .env.yandex | ForEach-Object {
  if ($_ -match '^\s*#|^\s*$') { return }
  $p = $_ -split '=', 2
  Set-Item "env:$($p[0].Trim())" $p[1].Trim()
}

python scripts/apply_ydb_schema.py
# → YDB schema applied.
```

Или одной командой:

```powershell
.\scripts\run_yandex.ps1
# (сначала применит schema, затем запустит API)
```

Таблицы описаны в `almanac/db/schema.yql`: workspaces, sessions, booking_requests, calendar_snapshots, device_tokens.

---

## Шаг 5. Запуск API

### Локально против облачной YDB (проверка)

```powershell
cd server
.\scripts\run_yandex.ps1
```

Проверка:

```powershell
(Invoke-WebRequest http://localhost:8080/health -UseBasicParsing).Content
# {"status":"ok"}
```

### Docker на VM

Подробно: [yandex-docker.md](yandex-docker.md)

```powershell
cd server
copy deploy\.env.yandex.example .env.yandex
# secrets\sa-key.json + заполнить .env.yandex
.\scripts\docker_yandex_up.ps1
```

```bash
cd server
cp deploy/.env.yandex.example .env.yandex
./scripts/docker_yandex_up.sh
```

### Образ в Yandex Container Registry

```bash
cd server
yc container registry configure-docker

docker build -t cr.yandex/<REGISTRY_ID>/almanac-api:latest .
docker push cr.yandex/<REGISTRY_ID>/almanac-api:latest
```

Разверните **Serverless Container** или **Compute Cloud VM** с этим образом, переменными из `.env.yandex` и volume `sa-key.json` → `/secrets/sa-key.json`.

---

## Шаг 6. TLS и домен

1. Зарегистрируйте домен, например `api.your-domain.ru`.
2. **Application Load Balancer** → target group → ваша VM:8080.
3. Сертификат Let's Encrypt или Yandex Certificate Manager.
4. Nginx на VM (опционально): см. `deploy/nginx.conf.example` — важны заголовки **Upgrade** для `/v1/ws/`.

`ALMANAC_PUBLIC_ORIGIN` должен совпадать с публичным HTTPS URL:

```env
ALMANAC_PUBLIC_ORIGIN=https://api.your-domain.ru
```

---

## Шаг 7. Flutter-клиент

В приложении **Ссылки и API**:

- **Server URL:** `https://api.your-domain.ru`
- **Проверить подключение**

Или при сборке:

```powershell
flutter build apk `
  --release `
  --obfuscate `
  --split-debug-info=build/debug-info `
  --dart-define=SERVER_URL=https://api.your-domain.ru `
  --dart-define=ENABLE_REMOTE_SYNC=true
```

App Links: [docs/app-links.md](../../docs/app-links.md) — `ALMANAC_ANDROID_SHA256_CERT`, iOS entitlements.

---

## Шаг 8. Проверка end-to-end

```bash
curl https://api.your-domain.ru/health

curl -H "X-Api-Key: YOUR-UUID-KEY" -H "X-Profile-Id: default" \
  https://api.your-domain.ru/v1/workspace
```

В приложении: создать booking session → открыть `https://api.your-domain.ru/join/TOKEN`.

---

## Частые ошибки

| Симптом | Решение |
|--------|---------|
| `Driver wait timeout` | Неверный endpoint/database path или SA без `ydb.editor` |
| `Permission denied` | Проверьте роли SA на каталог с YDB |
| WebSocket обрывается | ALB/nginx без `Upgrade`; см. nginx.conf.example |
| Deep link не открывает app | Настройте App Links + `ALMANAC_PUBLIC_ORIGIN` |
| `http:\localhost` в клиенте | Используйте `http://localhost:8080` |

---

## Локальная отладка YDB без облака

Эмулятор YDB в Docker:

```bash
cd server
docker compose up --build
# ydb-local:2136 + API с ALMANAC_DB_BACKEND=ydb
```

---

## Безопасность

- JSON-ключ SA — только на сервере / в Lockbox, не в чат и не в git.
- Для CI/CD — Yandex Lockbox или mounted secret в Container.
- Отдельный SA с минимальными правами только на нужную БД.
