#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <project-name> [config-path-relative-to-lean]" >&2
  exit 1
fi

PROJECT=$1
CONFIG_RELATIVE=${2:-"${PROJECT}/config.json"}

COMPOSE_CMD=${COMPOSE_CMD:-docker compose}
PROFILE=${COMPOSE_PROFILE:-backtest}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}

LOG_DIR=${LEAN_LOG_DIR:-lean-logs}
LOG_FILE=${LOG_DIR%/}/smoke_backtest.log

mkdir -p "${LOG_DIR}"

${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${SERVICE}" \
  --config "/workspace/lean/${CONFIG_RELATIVE}" \
  --data-folder /lean-data

echo "Smoke backtest finished. Logs mounted under ${LOG_DIR}" | tee -a "${LOG_FILE}"
