#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <config-path-relative-to-lean> [launcher-args...]" >&2
  exit 1
fi

CONFIG_PATH=$1
shift || true
ADDITIONAL_ARGS=("$@")

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPOSE_CMD=${COMPOSE_CMD:-docker compose}
PROFILE=${COMPOSE_PROFILE:-live}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}

LAUNCHER_ARGS=("--config" "/workspace/lean/${CONFIG_PATH}" "--data-folder" "/lean-data")

if [ ${#ADDITIONAL_ARGS[@]} -gt 0 ]; then
  LAUNCHER_ARGS+=("${ADDITIONAL_ARGS[@]}")
fi

ENV_FLAGS=()
for var in POLYGON_API_KEY IB_USER_NAME IB_ACCOUNT IB_PASSWORD LEAN_LIVE_BROKERAGE LEAN_LIVE_ACCOUNT_TYPE; do
  if [ -n "${!var:-}" ]; then
    ENV_FLAGS+=("--env" "${var}")
  fi
done

DETACH_ARGS=()
if [[ "${LEAN_ATTACH:-0}" != "1" ]]; then
  DETACH_ARGS+=("--detach")
fi

echo "Starting live trading container (profile=${PROFILE})"
set -x
${COMPOSE_CMD} --profile "${PROFILE}" run --rm ${DETACH_ARGS[@]} "${ENV_FLAGS[@]}" "${SERVICE}" "${LAUNCHER_ARGS[@]}"
