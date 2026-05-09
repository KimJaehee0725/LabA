#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/60-nextcloud.env" \
  "$ENV_DIR/99-demo.env"

require_cmd python3
require_cmd docker
require_cmd curl
require_cmd jq
require_cmd mktemp

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
NEXTCLOUD_URL="${NEXTCLOUD_URL:-https://${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}}"
NEXTCLOUD_SEED_USER="${NEXTCLOUD_SEED_USER:-${NEXTCLOUD_ADMIN_USER:-admin}}"
NEXTCLOUD_SEED_PASSWORD="${NEXTCLOUD_SEED_PASSWORD:-${NEXTCLOUD_SEED_APP_PASSWORD:-${NEXTCLOUD_ADMIN_APP_PASSWORD:-${DEMO_PASSWORD:-}}}}"
NEXTCLOUD_STRICT_APP_SEED="${NEXTCLOUD_STRICT_APP_SEED:-false}"
NEXTCLOUD_CA_CERT="${NEXTCLOUD_CA_CERT:-$LAB_PLATFORM_ROOT/nginx/ssl/lab-internal-ca.crt}"

CATALOG_RUNTIME_PATH="${DEMO_DATA_CATALOG:-${LAB_PLATFORM_ROOT}/data-model/lab-domain.v0.3.yaml}"
CATALOG_REPO_PATH="$SCRIPT_DIR/../data-model/lab-domain.v0.3.yaml"
CATALOG_PATH=""
if [[ -f "$CATALOG_RUNTIME_PATH" ]]; then
  CATALOG_PATH="$CATALOG_RUNTIME_PATH"
elif [[ -z "${DEMO_DATA_CATALOG:-}" && -f "$CATALOG_REPO_PATH" ]]; then
  CATALOG_PATH="$CATALOG_REPO_PATH"
else
  die "demo data catalog not found at $CATALOG_RUNTIME_PATH or $CATALOG_REPO_PATH"
fi

tmp_dir="$(mktemp -d)"
CATALOG_JSON="$tmp_dir/lab-domain.v0.3.json"
trap 'rm -rf "$tmp_dir"' EXIT

python3 - "$CATALOG_PATH" "$CATALOG_JSON" <<'PY'
import json
import sys

try:
    import yaml
except ModuleNotFoundError:
    sys.stderr.write("ERROR: Python module 'yaml' (PyYAML) is required to read the demo data catalog\n")
    sys.exit(3)

source, target = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}
with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=True)
PY

catalog_value() {
  local expression="$1"
  local fallback="$2"
  jq -er "$expression // empty" "$CATALOG_JSON" 2>/dev/null || printf '%s' "$fallback"
}

DOC_GROUP_FOLDER_NAME="${NEXTCLOUD_DOC_GROUP_FOLDER_NAME:-$(catalog_value 'first(.nextcloud.group_folders[]? | select(.phase == "seed")).name' 'Lab Demo Documents')}"
DOC_GROUP_NAME="${NEXTCLOUD_DOC_GROUP_NAME:-$(catalog_value 'first(.nextcloud.group_folders[]? | select(.phase == "seed")).group_ref' 'lab-member')}"
COLLECTIVE_NAME="${NEXTCLOUD_COLLECTIVE_NAME:-$(catalog_value 'first(.nextcloud.collectives[]? | select(.phase == "seed")).name' 'Lab Knowledge Base')}"
TABLE_NAME="${NEXTCLOUD_TABLE_NAME:-$(catalog_value 'first(.nextcloud.tables[]? | select(.phase == "seed")).name' 'Research Resources')}"
DECK_BOARD_NAME="${NEXTCLOUD_DECK_BOARD_NAME:-$(catalog_value 'first(.nextcloud.deck_boards[]? | select(.phase == "seed")).name' 'Research Ops')}"
CALENDAR_NAME="${NEXTCLOUD_CALENDAR_NAME:-$(catalog_value 'first(.nextcloud.calendars[]? | select(.phase == "seed")).uri' 'research-demo')}"

curl_tls_args=(-k)
if [[ -f "$NEXTCLOUD_CA_CERT" ]]; then
  curl_tls_args=(--cacert "$NEXTCLOUD_CA_CERT")
fi

seed_has_credentials=false
if [[ -n "$NEXTCLOUD_SEED_PASSWORD" && "$NEXTCLOUD_SEED_PASSWORD" != change-me* ]]; then
  seed_has_credentials=true
fi

occ() {
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ "$@"
}

optional_step() {
  local label="$1"
  shift
  if "$@"; then
    log "$label completed"
  elif [[ "$NEXTCLOUD_STRICT_APP_SEED" == "true" ]]; then
    die "$label failed"
  else
    log "WARNING: $label failed; continuing because NEXTCLOUD_STRICT_APP_SEED=false"
  fi
}

urlencode_path() {
  python3 - "$1" <<'PY'
import sys
from urllib.parse import quote

print("/".join(quote(part) for part in sys.argv[1].split("/")))
PY
}

nc_api_json() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  local args=(-sS "${curl_tls_args[@]}" -u "$NEXTCLOUD_SEED_USER:$NEXTCLOUD_SEED_PASSWORD" -H "OCS-APIRequest: true" -H "Accept: application/json" -H "Content-Type: application/json" -X "$method")
  if [[ -n "$payload" ]]; then
    args+=(--data "$payload")
  fi
  curl "${args[@]}" "$NEXTCLOUD_URL$path"
}

nc_plain_json() {
  local method="$1"
  local path="$2"
  local payload="${3:-}"
  local args=(-sS "${curl_tls_args[@]}" -u "$NEXTCLOUD_SEED_USER:$NEXTCLOUD_SEED_PASSWORD" -H "Accept: application/json" -H "Content-Type: application/json" -X "$method")
  if [[ -n "$payload" ]]; then
    args+=(--data "$payload")
  fi
  curl "${args[@]}" "$NEXTCLOUD_URL$path"
}

nc_api_form() {
  local method="$1"
  local path="$2"
  shift 2
  curl -sS "${curl_tls_args[@]}" \
    -u "$NEXTCLOUD_SEED_USER:$NEXTCLOUD_SEED_PASSWORD" \
    -H "OCS-APIRequest: true" \
    -H "Accept: application/json" \
    -X "$method" \
    "$@" \
    "$NEXTCLOUD_URL$path"
}

webdav_status() {
  local method="$1"
  local path="$2"
  shift 2
  local encoded_path
  encoded_path="$(urlencode_path "$path")"
  curl -sS "${curl_tls_args[@]}" \
    -u "$NEXTCLOUD_SEED_USER:$NEXTCLOUD_SEED_PASSWORD" \
    -X "$method" \
    -o /dev/null \
    -w '%{http_code}' \
    "$@" \
    "$NEXTCLOUD_URL/remote.php/dav/files/$NEXTCLOUD_SEED_USER/$encoded_path"
}

webdav_mkcol() {
  local path="$1"
  local status
  status="$(webdav_status MKCOL "$path")"
  [[ "$status" == "201" || "$status" == "405" ]]
}

webdav_put_text() {
  local path="$1"
  local content="$2"
  local file status
  file="$tmp_dir/upload.txt"
  printf '%s\n' "$content" >"$file"
  status="$(webdav_status PUT "$path" -T "$file")"
  [[ "$status" == "200" || "$status" == "201" || "$status" == "204" ]]
}

ensure_group_folder() {
  local folder_id create_out

  occ group:add "$DOC_GROUP_NAME" >/dev/null 2>&1 || true
  if occ user:info "$NEXTCLOUD_SEED_USER" >/dev/null 2>&1; then
    occ group:adduser "$DOC_GROUP_NAME" "$NEXTCLOUD_SEED_USER" >/dev/null 2>&1 || true
  fi

  folder_id="$(
    occ groupfolders:list --output=json 2>/dev/null \
      | jq -r --arg name "$DOC_GROUP_FOLDER_NAME" '
          to_entries[]?
          | select(.value.mount_point == $name or .value.mount_point == ("/" + $name))
          | (.value.id // .key)
        ' \
      | head -n 1
  )"
  if [[ -z "$folder_id" ]]; then
    create_out="$(occ groupfolders:create "$DOC_GROUP_FOLDER_NAME")"
    folder_id="$(sed -n 's/.*id \([0-9][0-9]*\).*/\1/p' <<<"$create_out" | tail -n 1)"
  fi
  if [[ -z "$folder_id" ]]; then
    folder_id="$(
      occ groupfolders:list --output=json 2>/dev/null \
        | jq -r --arg name "$DOC_GROUP_FOLDER_NAME" '
            to_entries[]?
            | select(.value.mount_point == $name or .value.mount_point == ("/" + $name))
            | (.value.id // .key)
          ' \
        | head -n 1
    )"
  fi
  [[ -n "$folder_id" ]] || die "failed to create or locate Nextcloud group folder: $DOC_GROUP_FOLDER_NAME"

  occ groupfolders:group "$folder_id" "$DOC_GROUP_NAME" write share delete >/dev/null
  occ groupfolders:quota "$folder_id" unlimited >/dev/null
  occ groupfolders:scan "$folder_id" >/dev/null || true
  log "Nextcloud group folder ready: $DOC_GROUP_FOLDER_NAME (id=$folder_id, group=$DOC_GROUP_NAME)"
}

seed_group_folder_files() {
  [[ "$seed_has_credentials" == "true" ]] || return 0

  webdav_mkcol "$DOC_GROUP_FOLDER_NAME"
  while IFS= read -r folder; do
    webdav_mkcol "$DOC_GROUP_FOLDER_NAME/$folder"
  done < <(jq -r '.nextcloud.group_folders[]? | select(.phase == "seed") | .folders[]?' "$CATALOG_JSON")

  webdav_put_text "$DOC_GROUP_FOLDER_NAME/README.md" "# Lab Demo Documents

This group folder is seeded for the v0.3 document hub smoke.

- 00-inbox: incoming notes and uploads
- 01-meeting-notes: recurring meeting records
- 02-literature: paper notes and reading artifacts
- 03-slides: presentation source material
- 04-reports: lab reports and validation summaries"

  webdav_put_text "$DOC_GROUP_FOLDER_NAME/01-meeting-notes/2026-05-09-platform-wave.md" "# Platform Wave Meeting Notes

## Agenda

- Confirm MLflow experiment and artifact smoke.
- Confirm Nextcloud Files, Collectives, Tables, Deck, Calendar, and Office entry points.
- Keep real credentials and research data out of seeded demo content."

  webdav_put_text "$DOC_GROUP_FOLDER_NAME/02-literature/paper-reading-template.md" "# Paper Reading

## Citation

## Summary

## Method Notes

## Follow-up Questions"

  webdav_put_text "$DOC_GROUP_FOLDER_NAME/04-reports/reproducibility-note.md" "# Reproducibility Note

This placeholder links code, experiment metadata, artifacts, and documents without containing private data."
}

seed_collectives() {
  [[ "$seed_has_credentials" == "true" ]] || return 0
  local response collective_id page_title pages_response

  response="$(nc_api_json GET "/ocs/v2.php/apps/collectives/api/v1.0/collectives")"
  collective_id="$(jq -r --arg name "$COLLECTIVE_NAME" '.ocs.data.collectives[]? | select(.name == $name) | .id' <<<"$response" | head -n 1)"
  if [[ -z "$collective_id" ]]; then
    nc_api_form POST "/ocs/v2.php/apps/collectives/api/v1.0/collectives" --data-urlencode "name=$COLLECTIVE_NAME" >/dev/null
    response="$(nc_api_json GET "/ocs/v2.php/apps/collectives/api/v1.0/collectives")"
    collective_id="$(jq -r --arg name "$COLLECTIVE_NAME" '.ocs.data.collectives[]? | select(.name == $name) | .id' <<<"$response" | head -n 1)"
  fi
  [[ -n "$collective_id" ]] || return 1

  pages_response="$(nc_api_json GET "/ocs/v2.php/apps/collectives/api/v1.0/collectives/$collective_id/pages")"
  while IFS= read -r page_title; do
    [[ -n "$page_title" ]] || continue
    if ! jq -e --arg title "$page_title" '.ocs.data.pages[]? | select(.title == $title)' <<<"$pages_response" >/dev/null; then
      nc_api_form POST "/ocs/v2.php/apps/collectives/api/v1.0/collectives/$collective_id/pages/0" --data-urlencode "title=$page_title" >/dev/null
    fi
  done < <(jq -r '.nextcloud.collectives[]? | select(.phase == "seed") | .pages[]?.title // empty' "$CATALOG_JSON")
}

seed_tables() {
  [[ "$seed_has_credentials" == "true" ]] || return 0
  local response table_id columns_response row_count payload column_id title_col type_col owner_col date_col status_col file_col github_col tags_col

  response="$(nc_api_json GET "/ocs/v2.php/apps/tables/api/2/tables")"
  table_id="$(jq -r --arg title "$TABLE_NAME" '.ocs.data[]? | select(.title == $title) | .id' <<<"$response" | head -n 1)"
  if [[ -z "$table_id" ]]; then
    payload="$(jq -nc --arg title "$TABLE_NAME" --arg description "Seeded v0.3 research resource index." '{title: $title, description: $description, template: "custom"}')"
    response="$(nc_api_json POST "/ocs/v2.php/apps/tables/api/2/tables" "$payload")"
    table_id="$(jq -r '.ocs.data.id // empty' <<<"$response")"
  fi
  [[ -n "$table_id" ]] || return 1
  return 0

  ensure_column() {
    local kind="$1"
    local title="$2"
    local extra_payload="${3:-}"
    local existing payload
    columns_response="$(nc_api_json GET "/ocs/v2.php/apps/tables/api/2/columns/table/$table_id")"
    existing="$(jq -r --arg title "$title" '.ocs.data[]? | select(.title == $title) | .id' <<<"$columns_response" | head -n 1)"
    if [[ -n "$existing" ]]; then
      printf '%s' "$existing"
      return 0
    fi
    payload="$(jq -nc --argjson baseNodeId "$table_id" --arg title "$title" --argjson extra "${extra_payload:-{}}" '{baseNodeId: $baseNodeId, baseNodeType: "table", title: $title} + $extra')"
    response="$(nc_api_json POST "/ocs/v2.php/apps/tables/api/2/columns/$kind" "$payload")"
    jq -r '.ocs.data.id // empty' <<<"$response"
  }

  title_col="$(ensure_column text "Title")"
  type_col="$(ensure_column selection "Type" '{"selectionOptions":"[{\"id\":1,\"label\":\"Paper\"},{\"id\":2,\"label\":\"Dataset\"},{\"id\":3,\"label\":\"Code\"},{\"id\":4,\"label\":\"Note\"}]"}')"
  owner_col="$(ensure_column text "Owner")"
  date_col="$(ensure_column datetime "Date" '{"subtype":"date"}')"
  status_col="$(ensure_column selection "Status" '{"selectionOptions":"[{\"id\":1,\"label\":\"New\"},{\"id\":2,\"label\":\"Reading\"},{\"id\":3,\"label\":\"Active\"},{\"id\":4,\"label\":\"Done\"}]"}')"
  file_col="$(ensure_column text "File Link")"
  github_col="$(ensure_column text "GitHub Link")"
  tags_col="$(ensure_column text "Tags")"

  row_count="$(nc_plain_json GET "/index.php/apps/tables/api/1/tables/$table_id/rows" | jq -r 'length')"
  if [[ "$row_count" == "0" ]]; then
    payload="$(jq -nc \
      --arg title_col "$title_col" --arg type_col "$type_col" --arg owner_col "$owner_col" \
      --arg date_col "$date_col" --arg status_col "$status_col" --arg file_col "$file_col" \
      --arg github_col "$github_col" --arg tags_col "$tags_col" \
      '{
        data: ({
        ($title_col): "Demo baseline resources",
        ($type_col): "3",
        ($owner_col): "Demo Member",
        ($date_col): "2026-05-09",
        ($status_col): "3",
        ($file_col): "Lab Demo Documents/04-reports/reproducibility-note.md",
        ($github_col): "https://hub.lab.snu.ac.kr/explore/repos",
        ($tags_col): "demo,mlflow,nextcloud"
      } | tojson)}')"
    nc_plain_json POST "/index.php/apps/tables/api/1/tables/$table_id/rows" "$payload" >/dev/null
  fi
}

seed_deck() {
  [[ "$seed_has_credentials" == "true" ]] || return 0
  local response board_id stack_id card_count payload card_json card_title card_stack card_due card_description

  response="$(nc_plain_json GET "/index.php/apps/deck/api/v1.0/boards?details=true")"
  board_id="$(jq -r --arg title "$DECK_BOARD_NAME" '.[]? | select(.title == $title) | .id' <<<"$response" | head -n 1)"
  if [[ -z "$board_id" ]]; then
    payload="$(jq -nc --arg title "$DECK_BOARD_NAME" '{title: $title, color: "2563eb"}')"
    response="$(nc_plain_json POST "/index.php/apps/deck/api/v1.0/boards" "$payload")"
    board_id="$(jq -r '.id // empty' <<<"$response")"
  fi
  [[ -n "$board_id" ]] || return 1

  nc_plain_json POST "/index.php/apps/deck/api/v1.0/boards/$board_id/acl" \
    "$(jq -nc --arg group "$DOC_GROUP_NAME" '{type: 1, participant: $group, permissionEdit: true, permissionShare: false, permissionManage: false}')" >/dev/null || true

  while IFS= read -r stack; do
    [[ -n "$stack" ]] || continue
    response="$(nc_plain_json GET "/index.php/apps/deck/api/v1.0/boards/$board_id/stacks")"
    stack_id="$(jq -r --arg title "$stack" '.[]? | select(.title == $title) | .id' <<<"$response" | head -n 1)"
    if [[ -z "$stack_id" ]]; then
      payload="$(jq -nc --arg title "$stack" --argjson order 999 '{title: $title, order: $order}')"
      nc_plain_json POST "/index.php/apps/deck/api/v1.0/boards/$board_id/stacks" "$payload" >/dev/null
    fi
  done < <(jq -r '.nextcloud.deck_boards[]? | select(.phase == "seed") | .stacks[]?' "$CATALOG_JSON")

  response="$(nc_plain_json GET "/index.php/apps/deck/api/v1.0/boards/$board_id/stacks")"
  while IFS= read -r card_json; do
    card_title="$(jq -r '.title' <<<"$card_json")"
    card_stack="$(jq -r '.stack' <<<"$card_json")"
    card_due="$(jq -r '.due // empty' <<<"$card_json")"
    card_description="$(jq -r '.description // ""' <<<"$card_json")"
    stack_id="$(jq -r --arg title "$card_stack" '.[]? | select(.title == $title) | .id' <<<"$response" | head -n 1)"
    [[ -n "$stack_id" ]] || return 1
    card_count="$(jq -r --arg stack "$card_stack" --arg title "$card_title" '.[]? | select(.title == $stack) | .cards[]? | select(.title == $title) | .id' <<<"$response" | wc -l)"
    if [[ "$card_count" != "0" ]]; then
      continue
    fi
    if [[ -n "$card_due" ]]; then
      card_due="${card_due}T09:00:00+00:00"
    fi
    payload="$(jq -nc --arg title "$card_title" --arg description "$card_description" --arg duedate "$card_due" '{title: $title, type: "plain", order: 10, description: $description, duedate: (if $duedate == "" then null else $duedate end)}')"
    nc_plain_json POST "/index.php/apps/deck/api/v1.0/boards/$board_id/stacks/$stack_id/cards" "$payload" >/dev/null
  done < <(jq -c '.nextcloud.deck_boards[]? | select(.phase == "seed") | .cards[]?' "$CATALOG_JSON")
}

seed_calendar() {
  if occ user:info "$NEXTCLOUD_SEED_USER" >/dev/null 2>&1; then
    occ dav:create-calendar "$NEXTCLOUD_SEED_USER" "$CALENDAR_NAME" >/dev/null 2>&1 || true
  fi
}

log "Using Nextcloud document hub catalog: $CATALOG_PATH"
ensure_group_folder
if [[ "$seed_has_credentials" == "true" ]]; then
  seed_group_folder_files
  optional_step "Collectives seed" seed_collectives
  optional_step "Tables seed" seed_tables
  optional_step "Deck seed" seed_deck
  optional_step "Calendar seed" seed_calendar
else
  log "skipping WebDAV/API document hub seed because NEXTCLOUD_SEED_PASSWORD or NEXTCLOUD_SEED_APP_PASSWORD is not configured"
fi

log "nextcloud document hub seed completed"
