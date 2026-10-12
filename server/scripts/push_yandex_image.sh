#!/usr/bin/env bash
# Push image to Yandex Container Registry.
# Usage: ./scripts/push_yandex_image.sh <REGISTRY_ID> [tag]
set -euo pipefail
cd "$(dirname "$0")/.."

REGISTRY_ID="${1:?Usage: push_yandex_image.sh REGISTRY_ID [tag]}"
TAG="${2:-latest}"
IMAGE="cr.yandex/${REGISTRY_ID}/almanac-api:${TAG}"

if ! command -v yc >/dev/null 2>&1; then
  echo "Install Yandex Cloud CLI: https://cloud.yandex.ru/docs/cli/quickstart"
  exit 1
fi

yc container registry configure-docker
docker build -t "$IMAGE" .
docker push "$IMAGE"
echo "Pushed $IMAGE"
echo "Use in Serverless Container or VM: $IMAGE"
