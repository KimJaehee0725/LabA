#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/65-grist.env"

require_cmd python3
require_cmd curl
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
  die "Grist seed catalog not found at $CATALOG_RUNTIME_PATH or $CATALOG_REPO_PATH"
fi

tmp_dir="$(mktemp -d)"
PLAN_JSON="$tmp_dir/grist-research-hub-plan.json"
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$CATALOG_PATH" "$PLAN_JSON" <<'PY'
import json
import sys

try:
    import yaml
except ModuleNotFoundError:
    sys.stderr.write("ERROR: Python module 'yaml' (PyYAML) is required to read the Grist seed catalog\n")
    sys.exit(3)

source, target = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    catalog = yaml.safe_load(handle) or {}

hub = ((catalog.get("grist") or {}).get("research_hub") or {})
if not hub:
    raise SystemExit("catalog is missing grist.research_hub")

def grist_column(column):
    col_id = column["id"]
    fields = {
        "label": column.get("label", col_id),
        "type": column.get("type", "Text"),
        "isFormula": False,
    }
    if "choices" in column:
        fields["widgetOptions"] = json.dumps(
            {"choices": column["choices"]},
            ensure_ascii=True,
            separators=(",", ":"),
        )
    return {"id": col_id, "fields": fields}

tables = []
for table in hub.get("tables", []):
    table_id = table["id"]
    columns = table.get("columns") or []
    column_ids = [column["id"] for column in columns]
    key_fields = table.get("key_fields") or [column_ids[0]]
    upsert_records = []
    for record in table.get("records", []):
        fields = {
            key: value
            for key, value in record.items()
            if key in column_ids and value is not None
        }
        required = {}
        for key in key_fields:
            if key not in fields:
                raise SystemExit(f"{table_id} record is missing key field {key}: {record!r}")
            required[key] = fields[key]
        upsert_records.append({"require": required, "fields": fields})
    tables.append(
        {
            "id": table_id,
            "columns": [grist_column(column) for column in columns],
            "key_fields": key_fields,
            "upsert_records": upsert_records,
        }
    )

plan = {
    "workspace_name": hub.get("workspace_name", "Lab Research Hub"),
    "document_name": hub.get("document_name", "Lab Research Hub"),
    "required_dashboard_kinds": hub.get("required_dashboard_kinds", []),
    "tables": tables,
}
with open(target, "w", encoding="utf-8") as handle:
    json.dump(plan, handle, ensure_ascii=True)
PY

GRIST_URL="${GRIST_URL:-https://${GRIST_DOMAIN:-data.lab.snu.ac.kr}}"
GRIST_URL="${GRIST_URL%/}"
GRIST_CA_CERT="${GRIST_CA_CERT:-$LAB_PLATFORM_ROOT/nginx/ssl/lab-internal-ca.crt}"
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
auth_label=""
if [[ -n "${GRIST_SEED_API_KEY:-}" && "${GRIST_SEED_API_KEY:-}" != change-me* ]]; then
  api_auth_args=(-H "Authorization: Bearer ${GRIST_SEED_API_KEY}")
  auth_label="API key"
elif [[ -n "${GRIST_BOOT_KEY:-}" && "${GRIST_BOOT_KEY:-}" != change-me* ]]; then
  api_auth_args=(-H "X-Boot-Key: ${GRIST_BOOT_KEY}")
  auth_label="boot key"
else
  die "set GRIST_SEED_API_KEY or GRIST_BOOT_KEY in $ENV_DIR/65-grist.env before seeding Grist"
fi

grist_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local output="$4"
  local args status
  args=(-sS "${curl_tls_args[@]}" "${api_auth_args[@]}" -H "Accept: application/json" -H "Content-Type: application/json" -X "$method" -o "$output" -w "%{http_code}")
  if [[ -n "$data" ]]; then
    args+=(-d "$data")
  fi
  status="$(curl "${args[@]}" "$GRIST_URL$path" || true)"
  [[ -n "$status" ]] || status="000"
  printf '%s' "$status"
}

grist_expect() {
  local method="$1"
  local path="$2"
  local data="$3"
  local output="$4"
  shift 4
  local status allowed body
  status="$(grist_api "$method" "$path" "$data" "$output")"
  for allowed in "$@"; do
    if [[ "$status" == "$allowed" ]]; then
      return 0
    fi
  done
  body="$(head -c 600 "$output" 2>/dev/null || true)"
  die "Grist API $method $path returned HTTP $status: $body"
}

extract_created_id() {
  jq -r '
    if type == "number" then tostring
    elif type == "string" then .
    elif type == "object" and (.id != null) then (.id | tostring)
    else empty
    end
  ' "$1"
}

ensure_workspace() {
  local output create_output payload workspace_id
  output="$tmp_dir/workspaces.json"
  grist_expect GET "/api/orgs/current/workspaces" "" "$output" 200
  workspace_id="$(jq -r --arg name "$GRIST_SEED_WORKSPACE_NAME" '.[]? | select(.name == $name) | .id' "$output" | head -n 1)"
  if [[ -n "$workspace_id" ]]; then
    printf '%s' "$workspace_id"
    return 0
  fi

  create_output="$tmp_dir/workspace-create.json"
  payload="$(jq -nc --arg name "$GRIST_SEED_WORKSPACE_NAME" '{name: $name}')"
  grist_expect POST "/api/orgs/current/workspaces" "$payload" "$create_output" 200 201
  workspace_id="$(extract_created_id "$create_output")"
  [[ -n "$workspace_id" ]] || die "Grist workspace create response did not include an id"
  printf '%s' "$workspace_id"
}

ensure_document() {
  local workspace_id="$1"
  local output create_output payload doc_id
  output="$tmp_dir/workspace-$workspace_id.json"
  grist_expect GET "/api/workspaces/$workspace_id" "" "$output" 200
  doc_id="$(jq -r --arg name "$GRIST_SEED_DOCUMENT_NAME" '.docs[]? | select(.name == $name) | .id' "$output" | head -n 1)"
  if [[ -n "$doc_id" ]]; then
    printf '%s' "$doc_id"
    return 0
  fi

  create_output="$tmp_dir/doc-create.json"
  payload="$(jq -nc --arg name "$GRIST_SEED_DOCUMENT_NAME" '{name: $name, isPinned: true}')"
  grist_expect POST "/api/workspaces/$workspace_id/docs" "$payload" "$create_output" 200 201
  doc_id="$(extract_created_id "$create_output")"
  [[ -n "$doc_id" ]] || die "Grist document create response did not include an id"
  printf '%s' "$doc_id"
}

ensure_grist_tables() {
  local doc_id="$1"
  local tables_output table_json table_id create_payload create_output columns_output missing_payload missing_count record_payload record_count record_output

  tables_output="$tmp_dir/tables.json"
  grist_expect GET "/api/docs/$doc_id/tables" "" "$tables_output" 200

  while IFS= read -r table_json; do
    table_id="$(jq -r '.id' <<<"$table_json")"
    if ! jq -e --arg id "$table_id" '.tables[]? | select(.id == $id)' "$tables_output" >/dev/null; then
      create_payload="$(jq -nc --argjson table "$table_json" '{tables: [{id: $table.id, columns: $table.columns}]}')"
      create_output="$tmp_dir/create-table-$table_id.json"
      grist_expect POST "/api/docs/$doc_id/tables" "$create_payload" "$create_output" 200 201
      log "Grist table created: $table_id"
    else
      log "Grist table already exists: $table_id"
    fi

    columns_output="$tmp_dir/columns-$table_id.json"
    grist_expect GET "/api/docs/$doc_id/tables/$table_id/columns" "" "$columns_output" 200
    missing_payload="$(
      jq -nc --argjson table "$table_json" --slurpfile existing "$columns_output" '
        ($existing[0].columns // [] | map(.id)) as $existingIds
        | {columns: [$table.columns[] | select(.id as $id | (($existingIds | index($id)) == null))]}
      '
    )"
    missing_count="$(jq -r '.columns | length' <<<"$missing_payload")"
    if [[ "$missing_count" -gt 0 ]]; then
      create_output="$tmp_dir/create-columns-$table_id.json"
      grist_expect POST "/api/docs/$doc_id/tables/$table_id/columns" "$missing_payload" "$create_output" 200 201
      log "Grist columns added for $table_id: $missing_count"
    fi

    record_count="$(jq -r '.upsert_records | length' <<<"$table_json")"
    if [[ "$record_count" -gt 0 ]]; then
      record_payload="$(jq -nc --argjson table "$table_json" '{records: $table.upsert_records}')"
      record_output="$tmp_dir/records-$table_id.json"
      grist_expect PUT "/api/docs/$doc_id/tables/$table_id/records?noparse=true" "$record_payload" "$record_output" 200
      log "Grist records upserted for $table_id: $record_count"
    fi
  done < <(jq -c '.tables[]' "$PLAN_JSON")
}

log "Using Grist seed catalog: $CATALOG_PATH"
log "Using Grist API authentication mode: $auth_label"
workspace_id="$(ensure_workspace)"
doc_id="$(ensure_document "$workspace_id")"
ensure_grist_tables "$doc_id"

echo "grist research hub seed completed"
echo "Workspace: $GRIST_SEED_WORKSPACE_NAME (id=$workspace_id)"
echo "Document: $GRIST_SEED_DOCUMENT_NAME (id=$doc_id)"
echo "Grist URL: ${GRIST_URL}/o/${GRIST_SINGLE_ORG:-lab}/doc/${doc_id}"
