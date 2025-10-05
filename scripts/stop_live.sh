#!/usr/bin/env bash
set -euo pipefail

COMPOSE_CMD=${COMPOSE_CMD:-docker compose}
SERVICE=${COMPOSE_SERVICE:-algorithm-runner}

${COMPOSE_CMD} stop "${SERVICE}"
