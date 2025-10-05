#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <tag> [registry]" >&2
  exit 1
fi

TAG=$1
REGISTRY=${2:-}
IMAGE_REFERENCE=$TAG

if [ -n "$REGISTRY" ]; then
  IMAGE_REFERENCE="${REGISTRY}/${TAG}"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to publish the Lean image" >&2
  exit 1
fi

if [ "${PUSH_IMAGE:-false}" != "true" ]; then
  read -rp "Push image ${IMAGE_REFERENCE}? [y/N] " confirm
  case "$confirm" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted"; exit 0 ;;
  esac
fi

docker push "${IMAGE_REFERENCE}"
