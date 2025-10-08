#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <config-path-relative-to-lean> [launcher-args...]" >&2
  exit 1
fi

CONFIG_PATH=$1
shift || true
ADDITIONAL_ARGS=("$@")

# Map friendly provider aliases to fully-qualified type names used by Lean
declare -A PROVIDER_ALIAS
PROVIDER_ALIAS[polygon]="QuantConnect.Lean.DataSource.Polygon.PolygonDataProvider"

declare -A HISTORY_PROVIDER_ALIAS
HISTORY_PROVIDER_ALIAS[polygon]="QuantConnect.Lean.DataSource.Polygon.PolygonDataProvider"

NEEDS_POLYGON_PROVIDER=0

function translate_provider_aliases() {
  local -n arr=$1
  local translated=()
  local i=0
  while [[ $i -lt ${#arr[@]} ]]; do
    local token=${arr[$i]}
    local effective_flag=${token}
    case "${token}" in
      --data-provider-historical)
        effective_flag="--history-provider"
        ;;&
      --data-provider|--data-provider-historical|--data-provider-live|--data-provider-event|--history-provider)
        translated+=("${effective_flag}")
        if [[ $((i+1)) -lt ${#arr[@]} ]]; then
          local value=${arr[$((i+1))]}
          local lowered=${value,,}
          if [[ ${effective_flag} == --history-provider ]]; then
            translated+=("${HISTORY_PROVIDER_ALIAS[$lowered]:-${value}}")
          else
            translated+=("${PROVIDER_ALIAS[$lowered]:-${value}}")
          fi
          if [[ ${lowered} == polygon ]]; then
            NEEDS_POLYGON_PROVIDER=1
          fi
          i=$((i+2))
          continue
        fi
        ;;
    esac
    translated+=("${token}")
    i=$((i+1))
  done
  arr=("${translated[@]}")
}

translate_provider_aliases ADDITIONAL_ARGS

# If the caller requested the polygon alias but didn't specify an explicit
# data-provider flag, ensure the Lean config uses the Polygon provider.
# Polygon data source implements history and live queue handlers but not IDataProvider,
# so we intentionally leave the data-provider setting alone.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPOSE_CMD=${COMPOSE_CMD:-docker compose}
PROFILE=${COMPOSE_PROFILE:-backtest}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}
BACKTEST_TIMEOUT=${LEAN_BACKTEST_TIMEOUT:-900}

PROJECT_ROOT=${LEAN_PROJECT_ROOT:-$(pwd)}
LEAN_DIR_HOST=${LEAN_DIR_HOST:-"${PROJECT_ROOT}/lean"}

LEAN_DIR_ABS=$(cd "${LEAN_DIR_HOST}" && pwd)
CONFIG_PATH_HOST="${LEAN_DIR_ABS}/${CONFIG_PATH}"
BASE_CONFIG_HOST="${LEAN_DIR_ABS}/lean.json"

CONFIG_DIR=$(dirname "${CONFIG_PATH}")
if [[ "${CONFIG_DIR}" == "." ]]; then
  CONFIG_DIR=""
fi

TMP_DIR="${LEAN_DIR_ABS}/.tmp"
mkdir -p "${TMP_DIR}"
MERGED_CONFIG_HOST=$(mktemp "${TMP_DIR}/merged-config-XXXXXX.json")

python3 - "$BASE_CONFIG_HOST" "$CONFIG_PATH_HOST" "$MERGED_CONFIG_HOST" <<'PY'
import json, sys
base_path, override_path, output_path = sys.argv[1:4]

def load(path):
    with open(path, 'r') as handle:
        return json.load(handle)

def deep_merge(target, source):
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_merge(target[key], value)
        else:
            target[key] = value

base_cfg = load(base_path)
override_cfg = load(override_path)
deep_merge(base_cfg, override_cfg)

with open(output_path, 'w') as handle:
    json.dump(base_cfg, handle, indent=2)
PY

CONFIG_CONTAINER=${MERGED_CONFIG_HOST/${LEAN_DIR_ABS}/\/workspace\/lean}

TIMESTAMP=$(date -u +"%Y-%m-%d_%H-%M-%S")
if [[ -n "${CONFIG_DIR}" ]]; then
  RESULTS_HOST="${LEAN_DIR_ABS%/}/${CONFIG_DIR}/backtests/${TIMESTAMP}"
  RESULTS_CONTAINER="/workspace/lean/${CONFIG_DIR}/backtests/${TIMESTAMP}"
else
  RESULTS_HOST="${LEAN_DIR_ABS%/}/backtests/${TIMESTAMP}"
  RESULTS_CONTAINER="/workspace/lean/backtests/${TIMESTAMP}"
fi

mkdir -p "${RESULTS_HOST}"

LAUNCHER_ARGS=(
  "--config" "${CONFIG_CONTAINER}"
  "--data-folder" "/lean-data"
  "--results-destination-folder" "${RESULTS_CONTAINER}"
  "--close-automatically" "true"
)

if [ ${#ADDITIONAL_ARGS[@]} -gt 0 ]; then
  LAUNCHER_ARGS+=("${ADDITIONAL_ARGS[@]}")
fi

TIMEOUT_BIN=$(command -v timeout || true)

DETACH_ARGS=()
if [[ "${LEAN_ATTACH:-0}" != "1" ]]; then
  DETACH_ARGS+=("--detach")
fi

set +e
set -x
if [ -n "${TIMEOUT_BIN}" ] && [ "${BACKTEST_TIMEOUT}" -gt 0 ]; then
  ${TIMEOUT_BIN} --signal=INT "${BACKTEST_TIMEOUT}" ${COMPOSE_CMD} --profile "${PROFILE}" run --rm ${DETACH_ARGS[@]} "${SERVICE}" "${LAUNCHER_ARGS[@]}"
  status=$?
  if [ ${status} -eq 124 ]; then
    echo "Backtest exceeded ${BACKTEST_TIMEOUT}s and was terminated." >&2
  fi
else
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm ${DETACH_ARGS[@]} "${SERVICE}" "${LAUNCHER_ARGS[@]}"
  status=$?
fi
set +x
set -e

exit ${status}
