#!/usr/bin/env bash
set -euo pipefail

VERSION=${IB_GATEWAY_VERSION:-stable}
TARGET=${1:-"./lean/ib-gateway"}

resolve_url() {
  local version="$1"
  case "$version" in
    latest|stable)
      local channel="${version}-standalone"
      local filename="ibgateway-${version}-standalone-linux-x64.sh"
      printf "https://download2.interactivebrokers.com/installers/ibgateway/%s/%s" "$channel" "$filename"
      ;;
    latest-*|stable-*)
      local channel="$version"
      local suffix=${version%%-standalone}
      local label=${suffix#*-}
      local filename="ibgateway-${label}-standalone-linux-x64.sh"
      printf "https://download2.interactivebrokers.com/installers/ibgateway/%s/%s" "$channel" "$filename"
      ;;
    *)
      local filename="ibgateway-${version}r-standalone-linux-x64.sh"
      printf "https://download2.interactivebrokers.com/installers/ibgateway/%s/%s" "$version" "$filename"
      ;;
  esac
}

URL=$(resolve_url "$VERSION")

TMPDIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "Downloading IB Gateway ${VERSION} from ${URL}..."
if ! curl -fsSL "${URL}" -o "${TMPDIR}/ibgateway.sh"; then
  echo "Failed to download IB Gateway version '${VERSION}'. Set IB_GATEWAY_VERSION to a valid value (e.g., stable, latest, 1019)." >&2
  exit 1
fi

chmod +x "${TMPDIR}/ibgateway.sh"
mkdir -p "${TARGET}"
TARGET_ABS=$(cd "${TARGET}" && pwd)
echo "Installing into ${TARGET_ABS}..."
"${TMPDIR}/ibgateway.sh" -q -overwrite -dir "${TARGET_ABS}" >/dev/null

# Ensure a compatible JRE (17.0.10) is available alongside the gateway
JRE_DIR="${TARGET_ABS}/jre"
if [[ ! -x "${JRE_DIR}/bin/java" ]]; then
# Use the JavaFX-enabled Zulu build by default so IB Gateway UI components load headlessly
JRE_URL=${IB_GATEWAY_JRE_URL:-https://cdn.azul.com/zulu/bin/zulu17.48.15-ca-fx-jre17.0.10-linux_x64.tar.gz}
  echo "Fetching Zulu JRE from ${JRE_URL}..."
  curl -fsSL "${JRE_URL}" -o "${TMPDIR}/zulu-jre.tar.gz"
  tar -xzf "${TMPDIR}/zulu-jre.tar.gz" -C "${TMPDIR}"
  EXTRACTED=$(find "${TMPDIR}" -maxdepth 1 -mindepth 1 -type d -name 'zulu17*' | head -n 1)
  if [[ -z "${EXTRACTED}" ]]; then
    echo "Failed to locate extracted JRE directory." >&2
    exit 1
  fi
  rm -rf "${JRE_DIR}"
  mv "${EXTRACTED}" "${JRE_DIR}"
fi

# Patch Install4J configuration to point at the bundled JRE
PREFERRED_JRE=${IB_GATEWAY_CONTAINER_JRE_PATH:-/ib-gateway/jre}
if [[ -d "${TARGET_ABS}/.install4j" ]]; then
  echo "${PREFERRED_JRE}" > "${TARGET_ABS}/.install4j/pref_jre.cfg"
  echo "${PREFERRED_JRE}" > "${TARGET_ABS}/.install4j/inst_jre.cfg"
fi

# Normalize executable/config names expected by IBAutomater
normalize_file() {
  local desired="$1"
  shift
  local candidate
  if [[ -f "${desired}" ]]; then
    return
  fi
  candidate=$(find "${TARGET_ABS}" -maxdepth 1 -type f "$@" -print | head -n 1 || true)
  if [[ -f "${desired}" ]]; then
    return
  fi
  if [[ -n "${candidate}" ]]; then
    mv "${candidate}" "${desired}"
  fi
}

normalize_file "${TARGET_ABS}/ibgateway" -name 'ibgateway*' ! -name 'ibgateway*.vmoptions'
chmod +x "${TARGET_ABS}/ibgateway" 2>/dev/null || true
normalize_file "${TARGET_ABS}/ibgateway.vmoptions" -name 'ibgateway*.vmoptions'

# Remove any leftover version-specific files to avoid rename conflicts
find "${TARGET_ABS}" -maxdepth 1 -type f -name 'ibgateway*' ! -name 'ibgateway' ! -name 'ibgateway.vmoptions' -delete || true
find "${TARGET_ABS}" -maxdepth 1 -type f -name 'ibgateway*.vmoptions' ! -name 'ibgateway.vmoptions' -delete || true

echo "IB Gateway ${VERSION} installed at ${TARGET_ABS}."
