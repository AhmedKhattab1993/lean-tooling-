#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TOOLING_ROOT=${SCRIPT_DIR}
PROJECT_ROOT_DEFAULT=$(pwd)

if [[ -n "${LEAN_PROJECT_ROOT:-}" ]]; then
  PROJECT_ROOT=${LEAN_PROJECT_ROOT}
elif [[ -f "${PROJECT_ROOT_DEFAULT}/docker-compose.yml" ]]; then
  PROJECT_ROOT=${PROJECT_ROOT_DEFAULT}
elif [[ -f "${SCRIPT_DIR}/../../docker-compose.yml" ]]; then
  PROJECT_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
else
  PROJECT_ROOT=${PROJECT_ROOT_DEFAULT}
fi

LEAN_DIR_DEFAULT="${PROJECT_ROOT}/lean"
LEAN_DIR=${LEAN_DIR:-${LEAN_DIR_DEFAULT}}
LEAN_JSON_DEFAULT="${LEAN_CONFIG:-${LEAN_DIR}/lean.json}"
LEAN_JSON=${LEAN_JSON_DEFAULT}

function command_exists() {
  command -v "$1" >/dev/null 2>&1
}

function detect_compose() {
  if [[ -n "${COMPOSE_CMD:-}" ]]; then
    echo "${COMPOSE_CMD}"
    return
  fi
  if command_exists docker && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
    return
  fi
  if command_exists docker-compose; then
    echo "docker-compose"
    return
  fi
  echo "" >&2
}

COMPOSE_CMD=$(detect_compose)

function ensure_prereqs() {
  if ! command_exists docker; then
    echo "Error: docker command not found. Install Docker and try again." >&2
    exit 1
  fi
  if [[ -z "${COMPOSE_CMD}" ]]; then
    echo "Error: docker compose (v2) or docker-compose (v1) is required." >&2
    exit 1
  fi
}

function read_data_folder() {
  if [[ ! -f "${LEAN_JSON}" ]]; then
    echo "/lean-data"
    return
  fi
  if ! command_exists python3; then
    echo "/lean-data"
    return
  fi
  local data_path
  data_path=$(python3 - "${LEAN_JSON}" <<'PY'
import json, os, sys
path = sys.argv[1]
with open(path, 'r') as fh:
    doc = json.load(fh)
value = doc.get('data-folder', 'data')
print(value)
PY
) || data_path="data"
  if [[ "${data_path}" = /* ]]; then
    echo "${data_path}"
  else
    echo "${LEAN_DIR%/}/${data_path}"
  fi
}

DATA_FOLDER_HOST=$(read_data_folder)

function print_version() {
  local version sha
  version="Lean Tooling CLI"
  if command_exists git; then
    sha=$(git -C "${TOOLING_ROOT}" rev-parse --short HEAD 2>/dev/null || true)
    if [[ -n "${sha}" ]]; then
      version+=" (git ${sha})"
    fi
  fi
  echo "${version}"
}

function print_help() {
  cat <<'HELP'
Lean Tooling CLI
Usage: ./lean <command> [options]

Commands:
  build            Build Lean engine Docker image from source
  backtest         Run a backtest using docker compose runtime
  live             Launch a live trading container
  download         Invoke Lean ToolBox utilities for data downloads
  stop             Stop the running Lean algorithm container
  ps               Show Lean-related containers
  logs             Tail Lean algorithm logs
  version          Show CLI version
  help             Show this help message

Examples:
  ./lean build
  ./lean backtest Nexora -- --start-date 2024-01-01 --end-date 2024-01-05
  ./lean live Nexora -- --detach
  ./lean download PolygonDataDownloader --ticker TSLA --from 2024-10-01 --to 2024-10-02 --resolution Minute
HELP
}

function ensure_compose_project_root() {
  if [[ ! -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
    echo "Error: docker-compose.yml not found. Set LEAN_PROJECT_ROOT or run from repository root." >&2
    exit 1
  fi
}

function resolve_project_config() {
  local project="$1"
  local explicit_config="$2"
  local config
  if [[ -n "${explicit_config}" ]]; then
    config="${explicit_config}"
  elif [[ -n "${project}" ]]; then
    config="${project}/config.json"
  else
    config="lean.json"
  fi
  if [[ ! -f "${LEAN_DIR}/${config}" ]]; then
    echo "Error: unable to find config '${config}' under ${LEAN_DIR}" >&2
    exit 1
  fi
  echo "${config}"
}

function handle_build() {
  ensure_prereqs
  ( cd "${PROJECT_ROOT}" && "${TOOLING_ROOT}/scripts/build_lean_image.sh" "$@" )
}

function handle_backtest() {
  ensure_prereqs
  ensure_compose_project_root
  local config=""
  local project=""
  local pass_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        [[ $# -lt 2 ]] && { echo "--config requires a path" >&2; exit 1; }
        config="$2"; shift 2 ;;
      -p|--project)
        [[ $# -lt 2 ]] && { echo "--project requires a name" >&2; exit 1; }
        project="$2"; shift 2 ;;
      --help|-h)
        cat <<'BHELP'
Usage: lean backtest [PROJECT] [--config <path>] [-- args]
If PROJECT is provided, config defaults to <PROJECT>/config.json under the lean/ folder.
Additional arguments after -- are passed directly to the launcher.
BHELP
        return 0 ;;
      --)
        shift
        pass_args+=("$@")
        break ;;
      -*)
        pass_args+=("$1")
        shift ;;
      *)
        if [[ -z "${project}" ]]; then
          project="$1"
        else
          pass_args+=("$1")
        fi
        shift ;;
    esac
  done
  local resolved
  resolved=$(resolve_project_config "${project}" "${config}")
  ( cd "${PROJECT_ROOT}" && \
    LEAN_DATA_HOST="${DATA_FOLDER_HOST}" \
    LEAN_PROJECT_ROOT="${PROJECT_ROOT}" \
    LEAN_DIR_HOST="${LEAN_DIR}" \
    "${TOOLING_ROOT}/scripts/run_backtest.sh" "${resolved}" "${pass_args[@]}" )
}

function ensure_live_env() {
  local missing=()
  for var in POLYGON_API_KEY; do
    [[ -z "${!var:-}" ]] && missing+=("${var}")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Warning: missing environment variables: ${missing[*]}. Live run may fail." >&2
  fi
}

function handle_live() {
  ensure_prereqs
  ensure_compose_project_root
  ensure_live_env
  local config=""
  local project=""
  local pass_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--config)
        [[ $# -lt 2 ]] && { echo "--config requires a path" >&2; exit 1; }
        config="$2"; shift 2 ;;
      -p|--project)
        [[ $# -lt 2 ]] && { echo "--project requires a name" >&2; exit 1; }
        project="$2"; shift 2 ;;
      --help|-h)
        cat <<'LHELP'
Usage: lean live [PROJECT] [--config <path>] [-- args]
Starts a live trading container using docker compose. Additional args after -- are passed to the launcher.
LHELP
        return 0 ;;
      --)
        shift
        pass_args+=("$@")
        break ;;
      -*)
        pass_args+=("$1")
        shift ;;
      *)
        if [[ -z "${project}" ]]; then
          project="$1"
        else
          pass_args+=("$1")
        fi
        shift ;;
    esac
  done
  local resolved
  resolved=$(resolve_project_config "${project}" "${config}")
  ( cd "${PROJECT_ROOT}" && LEAN_DATA_HOST="${DATA_FOLDER_HOST}" "${TOOLING_ROOT}/scripts/run_live.sh" "${resolved}" "${pass_args[@]}" )
}

function handle_stop() {
  ensure_prereqs
  ensure_compose_project_root
  ( cd "${PROJECT_ROOT}" && "${TOOLING_ROOT}/scripts/stop_live.sh" )
}

function handle_download() {
  ensure_prereqs
  ensure_compose_project_root
  if [[ $# -eq 0 ]]; then
    cat <<'DHELP'
Usage: lean download <ToolBox command> [args...]
Example: lean download PolygonDataDownloader --ticker TSLA --from 2024-10-01 --to 2024-10-02 --resolution Minute
DHELP
    exit 1
  fi
  ( cd "${PROJECT_ROOT}" && "${TOOLING_ROOT}/scripts/run_download.sh" "$@" )
}

function handle_ps() {
  ensure_prereqs
  ensure_compose_project_root
  ( cd "${PROJECT_ROOT}" && ${COMPOSE_CMD} ps )
}

function handle_logs() {
  ensure_prereqs
  ensure_compose_project_root
  local target="${COMPOSE_SERVICE:-algorithm-runner}"
  ( cd "${PROJECT_ROOT}" && ${COMPOSE_CMD} logs -f "${target}" )
}

function main() {
  if [[ $# -eq 0 ]]; then
    print_help
    exit 1
  fi
  case "$1" in
    help|-h|--help)
      print_help ;;
    version|-v|--version)
      print_version ;;
    build)
      shift
      handle_build "$@" ;;
    backtest)
      shift
      handle_backtest "$@" ;;
    live)
      shift
      handle_live "$@" ;;
    stop)
      shift
      handle_stop "$@" ;;
    download)
      shift
      handle_download "$@" ;;
    ps)
      shift
      handle_ps "$@" ;;
    logs)
      shift
      handle_logs "$@" ;;
    --version)
      print_version ;;
    --help)
      print_help ;;
    *)
      echo "Unknown command: $1" >&2
      print_help
      exit 1 ;;
  esac
}

main "$@"
