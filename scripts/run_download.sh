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
COMMAND+=("$@")

set -x
if [ ${#ENV_FLAGS[@]} -gt 0 ]; then
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${ENV_FLAGS[@]}" "${ENTRYPOINT[@]}" "${SERVICE}" "${COMMAND[@]}"
else
  ${COMPOSE_CMD} --profile "${PROFILE}" run --rm "${ENTRYPOINT[@]}" "${SERVICE}" "${COMMAND[@]}"
fi
