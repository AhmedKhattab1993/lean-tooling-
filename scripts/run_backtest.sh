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
PROFILE=${COMPOSE_PROFILE:-backtest}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}

LAUNCHER_ARGS=("--config" "/workspace/lean/${CONFIG_PATH}" "--data-folder" "/lean-data")

if [ ${#ADDITIONAL_ARGS[@]} -gt 0 ]; then
  LAUNCHER_ARGS+=("${ADDITIONAL_ARGS[@]}")
fi

set -x
${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${SERVICE}" "${LAUNCHER_ARGS[@]}"
