#!/usr/bin/env bash
# Build and run Almanac API in Docker against Yandex Cloud YDB.
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE=".env.yandex"
EXAMPLE="deploy/.env.yandex.example"
KEY_PATH="secrets/sa-key.json"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$EXAMPLE" "$ENV_FILE"
  echo "Created .env.yandex — fill ALMANAC_YDB_DATABASE and ALMANAC_PUBLIC_ORIGIN."
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "Place service account JSON at server/secrets/sa-key.json"
  exit 1
fi

if grep -q 'xxxxxxxx' "$ENV_FILE"; then
  echo "Replace ALMANAC_YDB_DATABASE placeholder in .env.yandex"
  exit 1
fi

echo "Building and starting almanac-api (YandexDB)..."
docker compose -f docker-compose.yandex.yml up --build -d

PORT="${ALMANAC_PUBLISH_PORT:-8080}"
echo "Waiting for http://localhost:${PORT}/health ..."
for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:${PORT}/health" >/dev/null 2>&1; then
    curl -fsS "http://localhost:${PORT}/health"
    echo
    echo "Server URL for Flutter: http://localhost:${PORT} (or your public domain)"
    exit 0
  fi
  sleep 2
done

echo "Health check failed — logs:"
echo "  docker compose -f docker-compose.yandex.yml logs -f almanac-api"
exit 1
