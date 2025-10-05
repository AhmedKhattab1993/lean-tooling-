#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TAG=${LEAN_IMAGE_TAG:-humblebot/lean-engine:local}
LEAN_CONFIGURATION=${LEAN_CONFIGURATION:-Release}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to build the Lean image" >&2
  exit 1
fi

echo "Building Lean engine image from source"
echo "  tag: ${TAG}"
echo "  configuration: ${LEAN_CONFIGURATION}"

docker build \
  --file "${REPO_ROOT}/Dockerfile" \
  --tag "${TAG}" \
  --build-arg "LEAN_CONFIGURATION=${LEAN_CONFIGURATION}" \
  "${REPO_ROOT}"
