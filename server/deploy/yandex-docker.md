# Almanac API в Docker + Yandex Cloud

Полная инструкция по облаку: [yandex-cloud-full.md](yandex-cloud-full.md)

## Что нужно заранее

1. **YandexDB** (Serverless) — endpoint и database path из [консоли](https://console.cloud.yandex.ru/)
2. **Сервисный аккаунт** с ролью `ydb.editor` → JSON-ключ → `server/secrets/sa-key.json`
3. **Docker** на вашем ПК или VM

---

## Быстрый старт (ПК или VM)

```powershell
cd server
copy deploy\.env.yandex.example .env.yandex
# отредактируйте .env.yandex:
#   ALMANAC_YDB_DATABASE=/ru-central1/b1g.../etn...
#   ALMANAC_PUBLIC_ORIGIN=https://api.your-domain.ru  (или http://IP:8080 для теста)

# положите ключ SA:
#   secrets\sa-key.json

.\scripts\docker_yandex_up.ps1
```

Linux / macOS:

```bash
cd server
cp deploy/.env.yandex.example .env.yandex
# edit .env.yandex + secrets/sa-key.json
chmod +x scripts/docker_yandex_up.sh
./scripts/docker_yandex_up.sh
```

Проверка:

```bash
curl http://localhost:8080/health
# {"status":"ok"}
```

Логи:

```bash
docker compose -f docker-compose.yandex.yml logs -f almanac-api
```

Остановка:

```bash
docker compose -f docker-compose.yandex.yml down
```

---

## Что делает контейнер

1. При старте применяет схему YDB (`schema.yql`) — повторный запуск безопасен
2. Запускает FastAPI на порту **8080**
3. Healthcheck: `GET /health`

Файлы:

| Файл | Назначение |
|------|------------|
| `Dockerfile` | образ API |
| `docker-compose.yandex.yml` | запуск против облачной YDB |
| `docker-entrypoint.sh` | schema + uvicorn |
| `.env.yandex` | секреты и endpoint YDB |

---

## Публикация в Yandex Container Registry

```bash
# Создайте registry в консоли: Container Registry → Create
yc container registry create --name almanac

# Registry ID вида crpXXXXXXXX
./scripts/push_yandex_image.sh crpXXXXXXXX latest
```

Windows:

```powershell
.\scripts\push_yandex_image.ps1 -RegistryId crpXXXXXXXX
```

---

## Запуск на VM (образ из Registry)

```bash
docker pull cr.yandex/crpXXXXXXXX/almanac-api:latest

docker run -d --name almanac-api --restart unless-stopped \
  -p 8080:8080 \
  --env-file .env.yandex \
  -e ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE=/secrets/sa-key.json \
  -v /opt/almanac/secrets/sa-key.json:/secrets/sa-key.json:ro \
  cr.yandex/crpXXXXXXXX/almanac-api:latest
```

Перед `docker run` скопируйте на VM:
- `.env.yandex` (заполненный)
- `sa-key.json` → `/opt/almanac/secrets/sa-key.json`

---

## Serverless Container (Yandex Cloud)

1. Container Registry → push образ (см. выше)
2. **Serverless Containers** → Create container
3. Образ: `cr.yandex/crpXXX/almanac-api:latest`
4. Port: **8080**
5. Переменные окружения (из `.env.yandex`):

| Variable | Example |
|----------|---------|
| `ALMANAC_PUBLIC_ORIGIN` | `https://api.your-domain.ru` |
| `ALMANAC_DB_BACKEND` | `ydb` |
| `ALMANAC_YDB_ENDPOINT` | `grpcs://ydb.serverless.yandexcloud.net:2135` |
| `ALMANAC_YDB_DATABASE` | `/ru-central1/b1g.../etn...` |
| `ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE` | `/secrets/sa-key.json` |
| `ALMANAC_CORS_ORIGINS` | `*` |

6. **Secret**: смонтируйте JSON-ключ SA как файл `/secrets/sa-key.json` (Lockbox → secret volume)
7. Создайте **HTTP trigger** / привяжите **Application Load Balancer** с TLS

> WebSocket (`/v1/ws/`) требует long-lived соединение — проверьте таймауты ALB.

---

## Подключение Flutter-приложения

После деплоя **Server URL** = ваш публичный HTTPS (или `http://VM_IP:8080` для теста):

- **Настройки → Ссылки и API → URL сервера**
- **API Key** — UUID из приложения (не из Yandex)
- **Profile ID** — `default`

---

## Частые ошибки

| Симптом | Решение |
|--------|---------|
| `Driver wait timeout` | Проверьте endpoint, database path, роль SA |
| `No such file: /secrets/sa-key.json` | Смонтируйте volume с ключом |
| Порт 8080 занят | `ALMANAC_PUBLISH_PORT=8081 docker compose ...` |
| Schema failed | Логи: `docker compose ... logs almanac-api` |
