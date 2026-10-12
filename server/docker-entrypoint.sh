#!/bin/sh
set -e

if [ "$ALMANAC_DB_BACKEND" = "ydb" ]; then
  echo "Applying YDB schema (idempotent)..."
  python scripts/apply_ydb_schema.py
fi

exec uvicorn almanac.main:app \
  --host "${ALMANAC_HOST:-0.0.0.0}" \
  --port "${ALMANAC_PORT:-8080}"
