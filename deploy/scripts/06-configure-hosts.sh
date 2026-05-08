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
  "${AUTH_DOMAIN:-auth.lab.snu.ac.kr}"
  "${GITEA_DOMAIN:-hub.lab.snu.ac.kr}"
  "${PLANE_DOMAIN:-lab.snu.ac.kr}"
  "${MLFLOW_DOMAIN:-mlflow.lab.snu.ac.kr}"
  "${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}"
  "${COLLABORA_DOMAIN:-office.lab.snu.ac.kr}"
  "${OVERLEAF_DOMAIN:-papers.lab.snu.ac.kr}"
  "${MINIO_CONSOLE_DOMAIN:-storage.lab.snu.ac.kr}"
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
