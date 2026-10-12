FROM python:3.12-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY almanac ./almanac
COPY landing ./landing
COPY scripts ./scripts
COPY docker-entrypoint.sh ./docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh

ENV ALMANAC_HOST=0.0.0.0
ENV ALMANAC_PORT=8080
ENV ALMANAC_DB_BACKEND=ydb
ENV ALMANAC_YDB_SERVICE_ACCOUNT_KEY_FILE=/secrets/sa-key.json

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS "http://127.0.0.1:${ALMANAC_PORT:-8080}/health" || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]
