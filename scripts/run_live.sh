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

PROJECT_ROOT=${LEAN_PROJECT_ROOT:-$(pwd)}
LEAN_DIR_HOST=${LEAN_DIR_HOST:-"${PROJECT_ROOT}/lean"}
LEAN_DIR_ABS=$(cd "${LEAN_DIR_HOST}" && pwd)
CONFIG_HOST_PATH="${LEAN_DIR_ABS}/${CONFIG_PATH}"
BASE_CONFIG_HOST="${LEAN_DIR_ABS}/lean.json"

TMP_DIR="${LEAN_DIR_ABS}/.tmp"
mkdir -p "${TMP_DIR}"
MERGED_CONFIG_HOST=$(mktemp "${TMP_DIR}/merged-live-config-XXXXXX.json")

normalize_ib_gateway() {
  local dir="${LEAN_DIR_ABS}/ib-gateway"
  [[ -d "${dir}" ]] || return

  if [[ ! -f "${dir}/ibgateway" ]]; then
    local candidate
    candidate=$(find "${dir}" -maxdepth 1 -type f -name 'ibgateway*' ! -name 'ibgateway*.vmoptions' -print | head -n 1 || true)
    if [[ -n "${candidate}" ]]; then
      mv "${candidate}" "${dir}/ibgateway"
    fi
  fi
  chmod +x "${dir}/ibgateway" 2>/dev/null || true

  if [[ ! -f "${dir}/ibgateway.vmoptions" ]]; then
    local vm
    vm=$(find "${dir}" -maxdepth 1 -type f -name 'ibgateway*.vmoptions' -print | head -n 1 || true)
    if [[ -n "${vm}" ]]; then
      mv "${vm}" "${dir}/ibgateway.vmoptions"
    fi
  fi

  find "${dir}" -maxdepth 1 -type f -name 'ibgateway*' ! -name 'ibgateway' ! -name 'ibgateway.vmoptions' -delete || true
  find "${dir}" -maxdepth 1 -type f -name 'ibgateway*.vmoptions' ! -name 'ibgateway.vmoptions' -delete || true
}

normalize_ib_gateway

python3 - "$BASE_CONFIG_HOST" "$CONFIG_HOST_PATH" "$MERGED_CONFIG_HOST" <<'PY'
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

PROJECT_SUBDIR=$(dirname "${CONFIG_PATH}")
if [ "${PROJECT_SUBDIR}" = "." ]; then
  PROJECT_SUBDIR=""
fi

if [ -n "${LEAN_RESULTS_DESTINATION:-}" ]; then
  RESULTS_CONTAINER="${LEAN_RESULTS_DESTINATION}"
  if [[ "${RESULTS_CONTAINER}" != /workspace/lean/* ]]; then
    echo "LEAN_RESULTS_DESTINATION must be an absolute container path under /workspace/lean" >&2
    exit 1
  fi
  HOST_PATH="${RESULTS_CONTAINER#/workspace/lean/}"
  RESULTS_HOST_DIR="${LEAN_DIR_ABS}/${HOST_PATH}"
else
  if [ -n "${PROJECT_SUBDIR}" ]; then
    RESULTS_HOST_DIR="${LEAN_DIR_ABS}/${PROJECT_SUBDIR}/live"
  else
    RESULTS_HOST_DIR="${LEAN_DIR_ABS}/live"
  fi
  RESULTS_CONTAINER=${RESULTS_HOST_DIR/${LEAN_DIR_ABS}/\/workspace\/lean}
fi

mkdir -p "${RESULTS_HOST_DIR}"

ENVIRONMENT_FROM_CONFIG=""
if [ -n "${CONFIG_HOST_PATH}" ] && command -v python3 >/dev/null 2>&1; then
  ENVIRONMENT_FROM_CONFIG=$(python3 - "$CONFIG_HOST_PATH" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path, 'r') as fh:
        data = json.load(fh)
except Exception:
    print("")
else:
    env = data.get('environment', '')
    print(env if isinstance(env, str) else "")
PY
)
fi

env_flag_present=0
for arg in "${ADDITIONAL_ARGS[@]}"; do
  if [ "${arg}" = "--environment" ]; then
    env_flag_present=1
    break
  fi
done

LAUNCHER_ARGS=("--config" "${CONFIG_CONTAINER}" "--data-folder" "/lean-data" "--results-destination-folder" "${RESULTS_CONTAINER}")

if [ ${env_flag_present} -eq 0 ] && [ -n "${ENVIRONMENT_FROM_CONFIG}" ]; then
  LAUNCHER_ARGS+=("--environment" "${ENVIRONMENT_FROM_CONFIG}")
fi

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
