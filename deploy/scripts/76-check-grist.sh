#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/65-grist.env"

require_cmd python3
require_cmd curl
require_cmd docker
require_cmd jq
require_cmd mktemp

LAB_DOMAIN_CATALOG_VERSION="${LAB_DOMAIN_CATALOG_VERSION:-v0.4}"
CATALOG_RUNTIME_PATH="${DEMO_DATA_CATALOG:-${LAB_PLATFORM_ROOT}/data-model/lab-domain.${LAB_DOMAIN_CATALOG_VERSION}.yaml}"
CATALOG_REPO_PATH="$SCRIPT_DIR/../data-model/lab-domain.${LAB_DOMAIN_CATALOG_VERSION}.yaml"
CATALOG_PATH=""
if [[ -f "$CATALOG_RUNTIME_PATH" ]]; then
  CATALOG_PATH="$CATALOG_RUNTIME_PATH"
elif [[ -z "${DEMO_DATA_CATALOG:-}" && -f "$CATALOG_REPO_PATH" ]]; then
  CATALOG_PATH="$CATALOG_REPO_PATH"
else
  die "Grist check catalog not found at $CATALOG_RUNTIME_PATH or $CATALOG_REPO_PATH"
fi

tmp_dir="$(mktemp -d)"
PLAN_JSON="$tmp_dir/grist-check-plan.json"
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$CATALOG_PATH" "$PLAN_JSON" <<'PY'
import json
import sys

try:
    import yaml
except ModuleNotFoundError:
    sys.stderr.write("ERROR: Python module 'yaml' (PyYAML) is required to read the Grist check catalog\n")
    sys.exit(3)

source, target = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    catalog = yaml.safe_load(handle) or {}
hub = ((catalog.get("grist") or {}).get("research_hub") or {})
if not hub:
    raise SystemExit("catalog is missing grist.research_hub")
plan = {
    "workspace_name": hub.get("workspace_name", "Lab Research Hub"),
    "document_name": hub.get("document_name", "Lab Research Hub"),
    "required_dashboard_kinds": hub.get("required_dashboard_kinds", []),
    "tables": [
        {
            "id": table["id"],
            "expected_records": len(table.get("records") or []),
        }
        for table in hub.get("tables", [])
    ],
}
with open(target, "w", encoding="utf-8") as handle:
    json.dump(plan, handle, ensure_ascii=True)
PY

GRIST_CONTAINER="${GRIST_CONTAINER:-grist}"
GRIST_URL="${GRIST_URL:-https://${GRIST_DOMAIN:-data.lab.snu.ac.kr}}"
GRIST_URL="${GRIST_URL%/}"
AUTH_URL="${AUTH_URL:-https://${AUTH_DOMAIN:-auth.lab.snu.ac.kr}}"
AUTH_URL="${AUTH_URL%/}"
GRIST_CA_CERT="${GRIST_CA_CERT:-$LAB_PLATFORM_ROOT/nginx/ssl/lab-internal-ca.crt}"
GRIST_OIDC_APP_SLUG="${GRIST_OIDC_APP_SLUG:-grist}"
GRIST_REQUIRE_API_CHECK="${GRIST_REQUIRE_API_CHECK:-true}"
GRIST_SEED_WORKSPACE_NAME="${GRIST_SEED_WORKSPACE_NAME:-$(jq -r '.workspace_name' "$PLAN_JSON")}"
GRIST_SEED_DOCUMENT_NAME="${GRIST_SEED_DOCUMENT_NAME:-$(jq -r '.document_name' "$PLAN_JSON")}"

curl_tls_args=(-k)
if [[ -f "$GRIST_CA_CERT" ]]; then
  curl_tls_args=(--cacert "$GRIST_CA_CERT")
fi
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_tls_args+=(--resolve "$CURL_RESOLVE")
fi

api_auth_args=()
if [[ -n "${GRIST_SEED_API_KEY:-}" && "${GRIST_SEED_API_KEY:-}" != change-me* ]]; then
  api_auth_args=(-H "Authorization: Bearer ${GRIST_SEED_API_KEY}")
elif [[ -n "${GRIST_BOOT_KEY:-}" && "${GRIST_BOOT_KEY:-}" != change-me* ]]; then
  api_auth_args=(-H "X-Boot-Key: ${GRIST_BOOT_KEY}")
elif [[ "$GRIST_REQUIRE_API_CHECK" == "true" ]]; then
  die "set GRIST_SEED_API_KEY or GRIST_BOOT_KEY in $ENV_DIR/65-grist.env, or set GRIST_REQUIRE_API_CHECK=false"
fi

grist_api() {
  local method="$1"
  local path="$2"
  local output="$3"
  local args status
  args=(-sS "${curl_tls_args[@]}" "${api_auth_args[@]}" -H "Accept: application/json" -X "$method" -o "$output" -w "%{http_code}")
  status="$(curl "${args[@]}" "$GRIST_URL$path" || true)"
  [[ -n "$status" ]] || status="000"
  printf '%s' "$status"
}

grist_expect() {
  local method="$1"
  local path="$2"
  local output="$3"
  shift 3
  local status allowed body
  status="$(grist_api "$method" "$path" "$output")"
  for allowed in "$@"; do
    if [[ "$status" == "$allowed" ]]; then
      return 0
    fi
  done
  body="$(head -c 600 "$output" 2>/dev/null || true)"
  die "Grist API $method $path returned HTTP $status: $body"
}

docker exec "$GRIST_CONTAINER" node -e "require('http').get('http://127.0.0.1:8484/status', r => process.exit(r.statusCode >= 200 && r.statusCode < 400 ? 0 : 1)).on('error', () => process.exit(1))"

status_output="$tmp_dir/status.txt"
status_code="$(curl -sS "${curl_tls_args[@]}" -o "$status_output" -w "%{http_code}" "$GRIST_URL/status" || true)"
[[ -n "$status_code" ]] || status_code="000"
[[ "$status_code" == "200" ]] || die "Grist external /status returned HTTP $status_code"
grep -qi 'alive' "$status_output" || die "Grist /status did not return the expected health text"

root_status="$(curl -sS "${curl_tls_args[@]}" -o /dev/null -w "%{http_code}" "$GRIST_URL/" || true)"
[[ -n "$root_status" ]] || root_status="000"
case "$root_status" in
  301|302|303|307|308|401|403)
    ;;
  200)
    die "Grist root returned HTTP 200 without authentication; expected redirect or denial"
    ;;
  *)
    die "Grist root returned unexpected HTTP $root_status"
    ;;
esac

discovery_output="$tmp_dir/grist-oidc-discovery.json"
discovery_status="$(curl -sS "${curl_tls_args[@]}" -o "$discovery_output" -w "%{http_code}" "$AUTH_URL/application/o/$GRIST_OIDC_APP_SLUG/.well-known/openid-configuration" || true)"
[[ -n "$discovery_status" ]] || discovery_status="000"
[[ "$discovery_status" == "200" ]] || die "Authentik Grist OIDC discovery returned HTTP $discovery_status"
jq -e --arg issuer "$AUTH_URL/application/o/$GRIST_OIDC_APP_SLUG/" '.issuer == $issuer' "$discovery_output" >/dev/null \
  || die "Authentik Grist OIDC discovery issuer mismatch"

if [[ "${#api_auth_args[@]}" -eq 0 ]]; then
  log "skipping Grist API seed checks because GRIST_REQUIRE_API_CHECK=false and no API or boot key is configured"
  echo "grist checks passed"
  exit 0
fi

workspaces_output="$tmp_dir/workspaces.json"
grist_expect GET "/api/orgs/current/workspaces" "$workspaces_output" 200
workspace_id="$(jq -r --arg name "$GRIST_SEED_WORKSPACE_NAME" '.[]? | select(.name == $name) | .id' "$workspaces_output" | head -n 1)"
[[ -n "$workspace_id" ]] || die "Grist workspace is missing: $GRIST_SEED_WORKSPACE_NAME"

workspace_output="$tmp_dir/workspace-$workspace_id.json"
grist_expect GET "/api/workspaces/$workspace_id" "$workspace_output" 200
doc_id="$(jq -r --arg name "$GRIST_SEED_DOCUMENT_NAME" '.docs[]? | select(.name == $name) | .id' "$workspace_output" | head -n 1)"
[[ -n "$doc_id" ]] || die "Grist document is missing: $GRIST_SEED_DOCUMENT_NAME"

tables_output="$tmp_dir/tables.json"
grist_expect GET "/api/docs/$doc_id/tables" "$tables_output" 200

while IFS= read -r table_json; do
  table_id="$(jq -r '.id' <<<"$table_json")"
  expected_records="$(jq -r '.expected_records' <<<"$table_json")"
  jq -e --arg id "$table_id" '.tables[]? | select(.id == $id)' "$tables_output" >/dev/null \
    || die "Grist table is missing: $table_id"
  if [[ "$expected_records" -gt 0 ]]; then
    records_output="$tmp_dir/records-$table_id.json"
    grist_expect GET "/api/docs/$doc_id/tables/$table_id/records" "$records_output" 200
    actual_records="$(jq -r '.records | length' "$records_output")"
    [[ "$actual_records" -gt 0 ]] || die "Grist table has no readable records: $table_id"
  fi
done < <(jq -c '.tables[]' "$PLAN_JSON")

dashboard_records="$tmp_dir/dashboard-pages-records.json"
grist_expect GET "/api/docs/$doc_id/tables/DashboardPages/records" "$dashboard_records" 200
required_kinds="$(jq -c '.required_dashboard_kinds' "$PLAN_JSON")"
jq -e --argjson required "$required_kinds" '
  [.records[]?.fields.Kind] as $actual
  | all($required[]; . as $kind | (($actual | index($kind)) != null))
' "$dashboard_records" >/dev/null || die "Grist DashboardPages is missing one or more required dashboard kinds"

views_output="$tmp_dir/grist-view-sections.json"
grist_expect GET "/api/docs/$doc_id/tables/_grist_Views_section/records?hidden=true" "$views_output" 200
jq -e '.records | length > 0' "$views_output" >/dev/null || die "Grist document has no view sections"

echo "grist checks passed"
