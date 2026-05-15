#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env"

STAGING_IP="${STAGING_IP:-}"
HOSTS_FILE="${HOSTS_FILE:-/etc/hosts}"
DRY_RUN="${DRY_RUN:-false}"

[[ -n "$STAGING_IP" ]] || die "STAGING_IP is required"

domains=(
  "${PORTAL_DOMAIN:-lab.example.ac.kr}"
  "${AUTH_DOMAIN:-auth.lab.example.ac.kr}"
  "${HULY_DOMAIN:-huly.lab.example.ac.kr}"
  "${FILES_DOMAIN:-files.lab.example.ac.kr}"
  "${S3_DOMAIN:-s3.lab.example.ac.kr}"
  "${HF_DOMAIN:-hf.lab.example.ac.kr}"
  "${MLFLOW_DOMAIN:-mlflow.lab.example.ac.kr}"
  "${OVERLEAF_DOMAIN:-overleaf.lab.example.ac.kr}"
)

begin="# lab-platform staging hosts BEGIN"
end="# lab-platform staging hosts END"
block="$begin"$'\n'
for domain in "${domains[@]}"; do
  block+="$STAGING_IP $domain"$'\n'
done
block+="$end"$'\n'

if [[ "$DRY_RUN" == "true" ]]; then
  printf '+ update %s with:\n%s' "$HOSTS_FILE" "$block"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if [[ -f "$HOSTS_FILE" ]]; then
  awk -v begin="$begin" -v end="$end" '
    $0 == begin {skip = 1; next}
    $0 == end {skip = 0; next}
    !skip {print}
  ' "$HOSTS_FILE" >"$tmp"
fi

printf '\n%s' "$block" >>"$tmp"
install -m 0644 "$tmp" "$HOSTS_FILE"
log "updated $HOSTS_FILE for lab-platform staging domains"
