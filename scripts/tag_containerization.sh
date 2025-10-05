#!/usr/bin/env bash
set -euo pipefail

TAG=${1:-containerization-preview}
IMAGE_TAG=${2:-humblebot/lean-engine:local}

cat <<INFO
To finalize the container migration:
  git tag ${TAG}
  git push origin ${TAG}
  docker push ${IMAGE_TAG}
INFO
