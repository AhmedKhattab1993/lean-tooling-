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
BACKTEST_TIMEOUT=${LEAN_BACKTEST_TIMEOUT:-900}

CONFIG_DIR=$(dirname "${CONFIG_PATH}")
if [[ "${CONFIG_DIR}" == "." ]]; then
  CONFIG_DIR=""
fi

TIMESTAMP=$(date -u +"%Y%m%d_%H-%M-%S")
RESULTS_RELATIVE="backtests/${TIMESTAMP}"

if [[ -n "${CONFIG_DIR}" ]]; then
  RESULTS_HOST="${REPO_ROOT}/lean/${CONFIG_DIR}/${RESULTS_RELATIVE}"
  RESULTS_CONTAINER="/workspace/lean/${CONFIG_DIR}/${RESULTS_RELATIVE}"
else
  RESULTS_HOST="${REPO_ROOT}/lean/${RESULTS_RELATIVE}"
  RESULTS_CONTAINER="/workspace/lean/${RESULTS_RELATIVE}"
fi

mkdir -p "${RESULTS_HOST}"

LAUNCHER_ARGS=(
  "--config" "/workspace/lean/${CONFIG_PATH}"
  "--data-folder" "/lean-data"
  "--results-destination-folder" "${RESULTS_CONTAINER}"
  "--close-automatically" "true"
)

if [ ${#ADDITIONAL_ARGS[@]} -gt 0 ]; then
  LAUNCHER_ARGS+=("${ADDITIONAL_ARGS[@]}")
fi

TIMEOUT_BIN=$(command -v timeout || true)

set +e
set -x
if [ -n "${TIMEOUT_BIN}" ] && [ "${BACKTEST_TIMEOUT}" -gt 0 ]; then
  ${TIMEOUT_BIN} --signal=INT "${BACKTEST_TIMEOUT}" ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${SERVICE}" "${LAUNCHER_ARGS[@]}"
  status=$?
  if [ ${status} -eq 124 ]; then
    echo "Backtest exceeded ${BACKTEST_TIMEOUT}s and was terminated." >&2
  fi
else
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${SERVICE}" "${LAUNCHER_ARGS[@]}"
  status=$?
fi
set +x
set -e

exit ${status}
