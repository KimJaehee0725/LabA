#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/60-nextcloud.env" "$ENV_DIR/99-demo.env"
require_cmd curl
require_cmd docker
require_cmd jq

NEXTCLOUD_URL="${NEXTCLOUD_URL:-https://${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}}"
COLLABORA_URL="${COLLABORA_URL:-https://${COLLABORA_DOMAIN:-office.lab.snu.ac.kr}}"
NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
NEXTCLOUD_CA_CERT="${NEXTCLOUD_CA_CERT:-$LAB_PLATFORM_ROOT/nginx/ssl/lab-internal-ca.crt}"
NEXTCLOUD_DOC_GROUP_FOLDER_NAME="${NEXTCLOUD_DOC_GROUP_FOLDER_NAME:-Lab Demo Documents}"
NEXTCLOUD_REQUIRED_APPS="${NEXTCLOUD_REQUIRED_APPS:-richdocuments,user_oidc,calendar,contacts,notes,tasks,groupfolders,collectives,tables,deck,integration_github}"
NEXTCLOUD_SMOKE_USER="${NEXTCLOUD_SMOKE_USER:-${NEXTCLOUD_SEED_USER:-${NEXTCLOUD_ADMIN_USER:-admin}}}"
NEXTCLOUD_SMOKE_PASSWORD="${NEXTCLOUD_SMOKE_PASSWORD:-${NEXTCLOUD_SEED_APP_PASSWORD:-${NEXTCLOUD_ADMIN_APP_PASSWORD:-${DEMO_PASSWORD:-}}}}"

curl_args=(-sSf)
curl_probe_args=(-sS -o /dev/null -w '%{http_code}')
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_args+=(--resolve "$CURL_RESOLVE")
  curl_probe_args+=(--resolve "$CURL_RESOLVE")
fi
if [[ -f "$NEXTCLOUD_CA_CERT" ]]; then
  curl_args+=(--cacert "$NEXTCLOUD_CA_CERT")
  curl_probe_args+=(--cacert "$NEXTCLOUD_CA_CERT")
else
  curl_args+=(-k)
  curl_probe_args+=(-k)
fi

occ() {
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"
}

curl "${curl_args[@]}" "$NEXTCLOUD_URL/status.php" >/dev/null
curl "${curl_args[@]}" "$COLLABORA_URL/hosting/discovery" >/dev/null
occ status >/dev/null

apps_json="$(occ app:list --output=json)"
IFS=',' read -r -a required_apps <<<"$NEXTCLOUD_REQUIRED_APPS"
for app in "${required_apps[@]}"; do
  app="${app//[[:space:]]/}"
  [[ -n "$app" ]] || continue
  jq -e --arg app "$app" '.enabled[$app] != null' <<<"$apps_json" >/dev/null || die "Nextcloud app is not enabled: $app"
done

oidc_provider="$(occ user_oidc:provider Authentik 2>/dev/null || true)"
grep -q 'openid email profile groups' <<<"$oidc_provider" || die "Nextcloud user_oidc provider does not expose expected scopes"
grep -Eq 'group.*provision|groupProvisioning' <<<"$oidc_provider" || die "Nextcloud user_oidc provider output did not include group provisioning"

groupfolders_json="$(occ groupfolders:list --output=json 2>/dev/null || printf '{}')"
jq -e --arg name "$NEXTCLOUD_DOC_GROUP_FOLDER_NAME" '
  to_entries[]?
  | select(.value.mount_point == $name or .value.mount_point == ("/" + $name))
' <<<"$groupfolders_json" >/dev/null || die "Nextcloud group folder is missing: $NEXTCLOUD_DOC_GROUP_FOLDER_NAME"

if [[ -n "$NEXTCLOUD_SMOKE_PASSWORD" && "$NEXTCLOUD_SMOKE_PASSWORD" != change-me* ]]; then
  smoke_path="lab-platform-webdav-smoke.txt"
  smoke_body="nextcloud webdav smoke $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  put_status="$(
    printf '%s\n' "$smoke_body" | curl "${curl_probe_args[@]}" \
      -u "$NEXTCLOUD_SMOKE_USER:$NEXTCLOUD_SMOKE_PASSWORD" \
      -X PUT \
      --data-binary @- \
      "$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_SMOKE_USER/$smoke_path"
  )"
  [[ "$put_status" == "200" || "$put_status" == "201" || "$put_status" == "204" ]] || die "Nextcloud WebDAV upload failed with HTTP $put_status"
  downloaded="$(curl "${curl_args[@]}" -u "$NEXTCLOUD_SMOKE_USER:$NEXTCLOUD_SMOKE_PASSWORD" "$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_SMOKE_USER/$smoke_path")"
  [[ "$downloaded" == "$smoke_body" ]] || die "Nextcloud WebDAV download content mismatch"
  curl "${curl_probe_args[@]}" -u "$NEXTCLOUD_SMOKE_USER:$NEXTCLOUD_SMOKE_PASSWORD" -X DELETE "$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_SMOKE_USER/$smoke_path" >/dev/null || true
else
  log "skipping Nextcloud WebDAV smoke because NEXTCLOUD_SMOKE_PASSWORD, NEXTCLOUD_SEED_APP_PASSWORD, or DEMO_PASSWORD is not configured"
fi

echo "nextcloud and collabora checks passed"
