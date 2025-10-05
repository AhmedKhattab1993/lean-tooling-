#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  cat <<USAGE >&2
Usage: $0 <toolbox-command> [args...]
Examples:
  $0 PolygonDataDownloader --ticker TSLA --from 2024-10-01 --to 2024-10-02 --resolution Minute
USAGE
  exit 1
fi

APP_NAME=$1
shift || true

PROJECT_ROOT=${LEAN_PROJECT_ROOT:-$(pwd)}
LEAN_DIR_HOST=${LEAN_DIR_HOST:-"${PROJECT_ROOT}/lean"}
LEAN_DIR_ABS=$(cd "${LEAN_DIR_HOST}" && pwd)
LEAN_JSON="${LEAN_DIR_ABS}/lean.json"

if [ -z "${POLYGON_API_KEY:-}" ] && [ -f "${LEAN_JSON}" ]; then
  if command -v python3 >/dev/null 2>&1; then
    POLYGON_API_KEY=$(python3 - "${LEAN_JSON}" <<'PY'
import json, sys
with open(sys.argv[1], 'r') as handle:
    doc = json.load(handle)
print(doc.get('polygon-api-key', ''))
PY
)
    if [ -n "${POLYGON_API_KEY}" ]; then
      export POLYGON_API_KEY
    fi
  fi
fi

>&2 echo "[lean download] POLYGON_API_KEY=${POLYGON_API_KEY:-<unset>}"

COMPOSE_CMD=${COMPOSE_CMD:-docker compose}
PROFILE=${COMPOSE_PROFILE:-utility}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}

ENV_FLAGS=()
for var in LEAN_CONFIG_FILE LEAN_DATA LEAN_LOGS LEAN_STORAGE POLYGON_API_KEY; do
  if [ -n "${!var:-}" ]; then
    ENV_FLAGS+=("--env" "${var}")
  fi
done

ENTRYPOINT=("--entrypoint" "dotnet")
COMMAND=("/Lean/ToolBox/QuantConnect.ToolBox.dll")
if [ -f "${LEAN_JSON}" ]; then
  COMMAND+=("--config" "/workspace/lean/lean.json")
fi
COMMAND+=("--app=${APP_NAME}")
if [ "$#" -gt 0 ]; then
  COMMAND+=("$@")
fi

set -x
if [ ${#ENV_FLAGS[@]} -gt 0 ]; then
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${ENV_FLAGS[@]}" "${ENTRYPOINT[@]}" "${SERVICE}" "${COMMAND[@]}"
else
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${ENTRYPOINT[@]}" "${SERVICE}" "${COMMAND[@]}"
fi
