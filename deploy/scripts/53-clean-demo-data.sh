#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/30-gitea.env" \
  "$ENV_DIR/40-plane.env" \
  "$ENV_DIR/99-demo.env"

require_cmd docker
require_cmd curl
require_cmd jq
require_cmd mktemp

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
PLANE_CONTAINER="${PLANE_CONTAINER:-plane-api}"
DEMO_USERNAME="${DEMO_USERNAME:-demo.member}"
DEMO_EMAIL="${DEMO_EMAIL:-demo.member@example.invalid}"
DEMO_GITEA_OWNER="${DEMO_GITEA_OWNER:-${GITEA_BOOTSTRAP_ADMIN_USER:-gitea-bootstrap-admin}}"
DEMO_PLANE_WORKSPACE_SLUG="${DEMO_PLANE_WORKSPACE_SLUG:-lab-demo}"
GITEA_BOOTSTRAP_ADMIN_TOKEN="${GITEA_BOOTSTRAP_ADMIN_TOKEN:-}"
GITEA_BASE_URL="${GITEA_EXTERNAL_URL:-https://hub.lab.snu.ac.kr}"
GITEA_BASE_URL="${GITEA_BASE_URL%/}"
GITEA_NETRC_HOST="${GITEA_BASE_URL#http://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST#https://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST%%/*}"

[[ -n "${GITEA_BOOTSTRAP_ADMIN_USER:-}" ]] || die "GITEA_BOOTSTRAP_ADMIN_USER must be configured"
[[ -n "${GITEA_BOOTSTRAP_ADMIN_PASSWORD:-}" || -n "$GITEA_BOOTSTRAP_ADMIN_TOKEN" ]] || die "GITEA_BOOTSTRAP_ADMIN_PASSWORD or GITEA_BOOTSTRAP_ADMIN_TOKEN must be configured"
[[ "$DEMO_GITEA_OWNER" == "$GITEA_BOOTSTRAP_ADMIN_USER" ]] || die "DEMO_GITEA_OWNER must be the configured Gitea bootstrap admin for this script"

docker exec \
  -e "DEMO_USERNAME=$DEMO_USERNAME" \
  "$AUTHENTIK_WORKER_CONTAINER" ak shell -c '
import os
from authentik.core.models import User

username = os.environ["DEMO_USERNAME"]
deleted, _ = User.objects.filter(username=username).delete()
print(f"authentik demo users deleted: {deleted}")
'

gitea_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$gitea_tmp_dir"' EXIT
chmod 0700 "$gitea_tmp_dir"
if [[ -n "$GITEA_BOOTSTRAP_ADMIN_TOKEN" ]]; then
  gitea_curl_auth_config="$gitea_tmp_dir/curl-auth.conf"
  printf 'header = "Authorization: token %s"\n' "$GITEA_BOOTSTRAP_ADMIN_TOKEN" >"$gitea_curl_auth_config"
  chmod 0600 "$gitea_curl_auth_config"
else
  gitea_netrc="$gitea_tmp_dir/netrc"
  cat >"$gitea_netrc" <<NETRC
machine $GITEA_NETRC_HOST
login $GITEA_BOOTSTRAP_ADMIN_USER
password $GITEA_BOOTSTRAP_ADMIN_PASSWORD
NETRC
  chmod 0600 "$gitea_netrc"
fi

for repo in lab-platform-demo vision-baseline-demo paper-template-demo; do
  output="$gitea_tmp_dir/$repo.json"
  curl_args=(-sS -k -X DELETE -o "$output" -w "%{http_code}")
  if [[ -n "${gitea_curl_auth_config:-}" ]]; then
    curl_args+=(--config "$gitea_curl_auth_config")
  else
    curl_args+=(--netrc-file "$gitea_netrc")
  fi
  curl_args+=("$GITEA_BASE_URL/api/v1/repos/$DEMO_GITEA_OWNER/$repo")
  status="$(curl "${curl_args[@]}")"
  if [[ "$status" == "204" || "$status" == "404" ]]; then
    log "Gitea demo repo removed or absent: $DEMO_GITEA_OWNER/$repo"
  else
    die "Gitea demo repo delete failed for $repo with HTTP $status"
  fi
done

docker exec \
  -e "DEMO_EMAIL=$DEMO_EMAIL" \
  -e "DEMO_PLANE_WORKSPACE_SLUG=$DEMO_PLANE_WORKSPACE_SLUG" \
  "$PLANE_CONTAINER" python manage.py shell -c '
import os
from plane.db.models import User, Workspace

workspace_slug = os.environ["DEMO_PLANE_WORKSPACE_SLUG"]
email = os.environ["DEMO_EMAIL"].lower()

workspace = Workspace.objects.filter(slug=workspace_slug).first()
if workspace is not None:
    workspace.delete(soft=False)

deleted, _ = User.objects.filter(email=email).delete()
print(f"plane demo workspace removed: {workspace_slug}")
print(f"plane demo users deleted: {deleted}")
'

echo "demo data cleanup completed"
