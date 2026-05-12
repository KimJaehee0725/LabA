#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
checks=(
  04-check-core.sh
  19-check-phase2-preflight.sh
  10-check-edge.sh
  20-check-authentik.sh
)

if [[ "${LABSTACK_INCLUDE_HULY:-false}" == "true" || "${LABSTACK_INCLUDE_HULY:-false}" == "1" ]]; then
  checks+=(
    23-check-phase3-huly-preflight.sh
    30-check-huly.sh
    32-check-huly-pilot.sh
  )
fi

if [[ "${LABSTACK_INCLUDE_MINIO:-false}" == "true" || "${LABSTACK_INCLUDE_MINIO:-false}" == "1" ]]; then
  checks+=(
    34-check-minio-storage.sh
    35-check-minio-backup-smoke.sh
  )
fi

if [[ "${LABSTACK_INCLUDE_HF_UI:-false}" == "true" || "${LABSTACK_INCLUDE_HF_UI:-false}" == "1" ]]; then
  checks+=(
    44-check-hf-ui.sh
  )
fi

if [[ "${LABSTACK_INCLUDE_OVERLEAF:-false}" == "true" || "${LABSTACK_INCLUDE_OVERLEAF:-false}" == "1" ]]; then
  checks+=(
    80-check-overleaf.sh
  )
fi

if [[ "${LABSTACK_INCLUDE_OPS_BASELINE:-false}" == "true" || "${LABSTACK_INCLUDE_OPS_BASELINE:-false}" == "1" ]]; then
  checks+=(
    99-check-ops-baseline.sh
  )
fi

for check in "${checks[@]}"; do
  echo "== $check =="
  "$SCRIPT_DIR/$check"
done
