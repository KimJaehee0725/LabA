#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checks=(
  04-check-core.sh
  10-check-edge.sh
  20-check-authentik.sh
  41-check-gitea.sh
  51-check-plane.sh
  60-check-mlflow.sh
  72-check-nextcloud.sh
  80-check-overleaf.sh
)

for check in "${checks[@]}"; do
  echo "== $check =="
  "$SCRIPT_DIR/$check"
done
