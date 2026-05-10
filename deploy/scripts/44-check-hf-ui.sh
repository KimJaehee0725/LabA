#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PHASE5_REQUIRE_REAL_DOMAINS_INCOMING="${PHASE5_REQUIRE_REAL_DOMAINS:-}"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/45-hf-ui.env"

AUTH_DOMAIN="${AUTH_DOMAIN:-auth.lab.example.ac.kr}"
HF_DOMAIN="${HF_DOMAIN:-hf.lab.example.ac.kr}"
S3_DOMAIN="${S3_DOMAIN:-s3.lab.example.ac.kr}"
HF_UI_CONTAINER="${HF_UI_CONTAINER:-hf-ui}"
HF_UI_PUBLIC_URL="${HF_UI_PUBLIC_URL:-https://${HF_DOMAIN}}"
HF_UI_PUBLIC_URL="${HF_UI_PUBLIC_URL%/}"
PHASE5_REQUIRE_REAL_DOMAINS="${PHASE5_REQUIRE_REAL_DOMAINS:-true}"
if [[ -n "$PHASE5_REQUIRE_REAL_DOMAINS_INCOMING" ]]; then
  PHASE5_REQUIRE_REAL_DOMAINS="$PHASE5_REQUIRE_REAL_DOMAINS_INCOMING"
fi

status=0
check_tmp_dir="$(mktemp -d)"
trap 'rm -rf "$check_tmp_dir"' EXIT

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

is_true() {
  [[ "${1:-}" == "true" || "${1:-}" == "1" || "${1:-}" == "yes" ]]
}

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" ||
    "$value" == change-me* ||
    "$value" == CHANGE-ME* ||
    "$value" == todo* ||
    "$value" == TODO* ]]
}

is_example_value() {
  local value="${1:-}"
  [[ "$value" == *example.edu* || "$value" == *example.ac.kr* ]]
}

check_real_value() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  elif is_true "$PHASE5_REQUIRE_REAL_DOMAINS" && is_example_value "$value"; then
    fail "$name still uses an example domain/value"
  else
    ok "$name is set"
  fi
}

check_secret_var() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set without printing its value"
  fi
}

check_container() {
  local name="$1"
  local state health
  if ! docker inspect "$name" >/dev/null 2>&1; then
    fail "missing container: $name"
    return
  fi
  state="$(docker inspect -f '{{.State.Status}}' "$name")"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name")"
  if [[ "$state" != "running" ]]; then
    fail "$name is not running: $state"
    return
  fi
  if [[ -n "$health" && "$health" != "healthy" ]]; then
    fail "$name health is $health"
    return
  fi
  ok "$name is running${health:+ and $health}"
}

check_no_host_ports() {
  local name="$1"
  local ports
  ports="$(docker inspect -f '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$name" 2>/dev/null || true)"
  if [[ -n "$ports" ]]; then
    fail "$name publishes host ports: $ports"
  else
    ok "$name publishes no host ports"
  fi
}

json_value() {
  local expr="$1"
  python3 -c '
import json
import sys

expr = sys.argv[1]
data = json.load(sys.stdin)
value = data
for part in expr.split("."):
    if not part:
        continue
    if part.isdigit():
        value = value[int(part)]
    else:
        value = value[part]
print(value)
' "$expr"
}

json_first_string() {
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
for key in sys.argv[1:]:
    value = data.get(key)
    if isinstance(value, str) and value:
        print(value)
        break
' "$@"
}

require_cmd curl
require_cmd docker
require_cmd python3

curl_resolve_args=()
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  IFS=',' read -r -a curl_resolve_values <<<"$CURL_RESOLVE"
  for curl_resolve in "${curl_resolve_values[@]}"; do
    curl_resolve="${curl_resolve//[[:space:]]/}"
    [[ -n "$curl_resolve" ]] || continue
    curl_resolve_args+=(--resolve "$curl_resolve")
  done
elif [[ "${STAGING_IP:-}" != "" ]]; then
  curl_resolve_args+=(--resolve "${HF_DOMAIN}:443:${STAGING_IP}")
  curl_resolve_args+=(--resolve "${S3_DOMAIN}:443:${STAGING_IP}")
  curl_resolve_args+=(--resolve "${AUTH_DOMAIN}:443:${STAGING_IP}")
fi
curl_probe_args=(-ksS --noproxy "*" "${curl_resolve_args[@]}")

auth_headers=()
if is_true "${HF_UI_ALLOW_STAGING_BYPASS:-false}"; then
  check_secret_var HF_UI_STAGING_BYPASS_TOKEN
  auth_headers=(-H "X-HF-UI-Staging-Token: ${HF_UI_STAGING_BYPASS_TOKEN:-}")
else
  log "HF_UI_ALLOW_STAGING_BYPASS is not enabled; automated catalog checks require browser OIDC"
fi

check_real_value HF_DOMAIN
check_real_value AUTH_DOMAIN
check_real_value S3_DOMAIN
check_secret_var HF_UI_SESSION_SECRET
check_secret_var HF_UI_OIDC_CLIENT_SECRET
check_secret_var HF_UI_S3_ACCESS_KEY
check_secret_var HF_UI_S3_SECRET_KEY

check_container "$HF_UI_CONTAINER"
check_no_host_ports "$HF_UI_CONTAINER"

health_json="$(curl "${curl_probe_args[@]}" "$HF_UI_PUBLIC_URL/api/health" || true)"
if [[ "$(printf '%s' "$health_json" | json_value status 2>/dev/null || true)" == "ok" ]]; then
  ok "HF UI health returned ok"
else
  fail "HF UI health failed"
fi

index_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$HF_UI_PUBLIC_URL/" || true)"
if [[ "$index_status" =~ ^[23][0-9][0-9]$ ]]; then
  ok "HF UI index returned HTTP $index_status"
else
  fail "HF UI index returned HTTP ${index_status:-000}"
fi

discovery_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "https://${AUTH_DOMAIN}/application/o/hf-ui/.well-known/openid-configuration" || true)"
if [[ "$discovery_status" =~ ^[23][0-9][0-9]$ ]]; then
  ok "Authentik HF UI OIDC discovery returned HTTP $discovery_status"
else
  fail "Authentik HF UI OIDC discovery returned HTTP ${discovery_status:-000}"
fi

if ((${#auth_headers[@]})); then
  models_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/models" || true)"
  datasets_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/datasets" || true)"
  model_count="$(printf '%s' "$models_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("items", [])))' 2>/dev/null || printf 0)"
  dataset_count="$(printf '%s' "$datasets_json" | python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("items", [])))' 2>/dev/null || printf 0)"
  if ((model_count >= 1)); then ok "model list contains $model_count item(s)"; else fail "model list is empty"; fi
  if ((dataset_count >= 1)); then ok "dataset list contains $dataset_count item(s)"; else fail "dataset list is empty"; fi

  detail_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/model/demo/tiny-transformer" || true)"
  if printf '%s' "$detail_json" | grep -q "Tiny Transformer Demo"; then
    ok "model detail and README render source are available"
  else
    fail "model detail did not include expected sample"
  fi

  files_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/model/demo/tiny-transformer/files" || true)"
  if printf '%s' "$files_json" | grep -q "model.safetensors"; then
    ok "model file tree includes model.safetensors"
  else
    fail "model file tree missing model.safetensors"
  fi

  dataset_detail_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini" || true)"
  if printf '%s' "$dataset_detail_json" | grep -q "Sentiment Mini Dataset"; then
    ok "dataset detail and README render source are available"
  else
    fail "dataset detail did not include expected sample"
  fi

  dataset_files_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/files" || true)"
  if printf '%s' "$dataset_files_json" | grep -q "train.jsonl" &&
    printf '%s' "$dataset_files_json" | grep -q "validation.csv" &&
    printf '%s' "$dataset_files_json" | grep -q "test.json" &&
    printf '%s' "$dataset_files_json" | grep -q "sample.parquet"; then
    ok "dataset file tree includes preview sample splits"
  else
    fail "dataset file tree missing one or more preview sample splits"
  fi

  train_preview_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/preview?path=train.jsonl" || true)"
  if printf '%s' "$train_preview_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
stats = {item.get("column"): item for item in data.get("stats", [])}
assert data.get("file", {}).get("format") == "jsonl"
assert len(data.get("rows", [])) >= 1
assert stats.get("text", {}).get("kind") == "text_length"
assert stats.get("label", {}).get("kind") == "categorical"
assert stats.get("reviewed", {}).get("kind") == "categorical"
' 2>/dev/null; then
    ok "JSONL preview returns rows plus categorical and text stats"
  else
    fail "JSONL preview missing expected rows or stats"
  fi

  validation_preview_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/preview?path=validation.csv" || true)"
  if printf '%s' "$validation_preview_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
stats = {item.get("column"): item for item in data.get("stats", [])}
assert data.get("file", {}).get("format") == "csv"
assert len(data.get("rows", [])) >= 1
assert stats.get("score", {}).get("kind") == "numeric"
assert stats.get("score", {}).get("mean") is not None
assert stats.get("tokens", {}).get("kind") == "numeric"
' 2>/dev/null; then
    ok "CSV preview returns numeric stats"
  else
    fail "CSV preview missing expected numeric stats"
  fi

  test_preview_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/preview?path=test.json" || true)"
  if printf '%s' "$test_preview_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
schema = {item.get("name") for item in data.get("schema", [])}
assert data.get("file", {}).get("format") == "json"
assert len(data.get("rows", [])) >= 1
assert {"id", "text", "label"}.issubset(schema)
' 2>/dev/null; then
    ok "JSON preview returns schema and rows"
  else
    fail "JSON preview missing expected schema or rows"
  fi

  parquet_preview_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/preview?path=sample.parquet" || true)"
  if printf '%s' "$parquet_preview_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
file_info = data.get("file", {})
schema_items = data.get("schema", [])
schema = {item.get("name") for item in schema_items}
stats = {item.get("column"): item for item in data.get("stats", [])}
assert file_info.get("format") == "parquet"
assert len(data.get("rows", [])) >= 1
assert {"id", "text", "label", "score", "tokens", "reviewed"}.issubset(schema)
assert any(item.get("source_type") for item in schema_items)
assert stats.get("score", {}).get("kind") == "numeric"
assert stats.get("score", {}).get("mean") is not None
assert stats.get("tokens", {}).get("kind") == "numeric"
' 2>/dev/null; then
    ok "Parquet preview returns rows, schema, source type, and numeric stats"
  else
    fail "Parquet preview missing expected rows, schema, source type, or numeric stats"
  fi

  presign_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" -X POST "$HF_UI_PUBLIC_URL/api/files/presign?kind=model&owner=demo&name=tiny-transformer&path=model.safetensors" || true)"
  presign_url="$(printf '%s' "$presign_json" | json_value url 2>/dev/null || true)"
  if [[ "$presign_url" == https://${S3_DOMAIN}/* ]]; then
    ok "presigned download URL uses public S3 domain"
    if curl "${curl_probe_args[@]}" -f -o /tmp/hf-ui-download-smoke.bin "$presign_url"; then
      ok "presigned download succeeded"
    else
      fail "presigned download failed"
    fi
  else
    fail "presigned URL missing or not on public S3 domain"
  fi

  upload_path="smoke/direct-upload-$(date -u +%Y%m%dT%H%M%SZ)-$$.jsonl"
  upload_file="$check_tmp_dir/hf-ui-upload-smoke.jsonl"
  cat >"$upload_file" <<EOF_UPLOAD_SMOKE
{"id":"hf-ui-upload-smoke","text":"browser direct upload smoke","label":"smoke"}
EOF_UPLOAD_SMOKE

  upload_presign_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" -X POST -G \
    --data-urlencode "action=upload" \
    --data-urlencode "kind=dataset" \
    --data-urlencode "owner=demo" \
    --data-urlencode "name=sentiment-mini" \
    --data-urlencode "path=${upload_path}" \
    --data-urlencode "overwrite=false" \
    "$HF_UI_PUBLIC_URL/api/files/presign" || true)"
  upload_url="$(printf '%s' "$upload_presign_json" | json_first_string url upload_url put_url 2>/dev/null || true)"
  if [[ "$upload_url" == https://${S3_DOMAIN}/* ]]; then
    ok "presigned upload URL uses public S3 domain"

    preflight_headers="$check_tmp_dir/hf-ui-upload-preflight.headers"
    preflight_status="$(curl "${curl_probe_args[@]}" -o /dev/null -D "$preflight_headers" -w '%{http_code}' \
      -X OPTIONS \
      -H "Origin: ${HF_UI_PUBLIC_URL}" \
      -H "Access-Control-Request-Method: PUT" \
      -H "Access-Control-Request-Headers: content-type" \
      "$upload_url" || true)"
    if [[ "$preflight_status" =~ ^2[0-9][0-9]$ ]] &&
      grep -iq '^access-control-allow-methods:.*PUT' "$preflight_headers"; then
      ok "presigned upload URL CORS preflight allows PUT"
    elif [[ "$preflight_status" == "000" ]]; then
      log "warn: presigned upload URL CORS preflight could not be reached"
    else
      fail "presigned upload URL CORS preflight did not allow PUT (HTTP ${preflight_status:-000})"
    fi

    if curl "${curl_probe_args[@]}" -f -X PUT \
      -H "Content-Type: application/x-ndjson" \
      --data-binary "@$upload_file" \
      "$upload_url" >/dev/null; then
      ok "presigned direct upload PUT succeeded"
    else
      fail "presigned direct upload PUT failed"
    fi

    uploaded_files_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/files" || true)"
    if printf '%s' "$uploaded_files_json" | grep -Fq "$upload_path"; then
      ok "dataset file tree includes direct upload smoke object"
    else
      fail "dataset file tree missing direct upload smoke object"
    fi

    uploaded_preview_json="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" -G \
      --data-urlencode "path=${upload_path}" \
      "$HF_UI_PUBLIC_URL/api/dataset/demo/sentiment-mini/preview" || true)"
    if printf '%s' "$uploaded_preview_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
assert data.get("file", {}).get("format") == "jsonl"
rows = data.get("rows", [])
assert any(row.get("id") == "hf-ui-upload-smoke" for row in rows)
' 2>/dev/null; then
      ok "direct upload smoke JSONL preview is readable"
    else
      fail "direct upload smoke JSONL preview is not readable"
    fi

    duplicate_body="$check_tmp_dir/hf-ui-upload-duplicate.json"
    duplicate_status="$(curl "${curl_probe_args[@]}" "${auth_headers[@]}" -o "$duplicate_body" -w '%{http_code}' -X POST -G \
      --data-urlencode "action=upload" \
      --data-urlencode "kind=dataset" \
      --data-urlencode "owner=demo" \
      --data-urlencode "name=sentiment-mini" \
      --data-urlencode "path=${upload_path}" \
      --data-urlencode "overwrite=false" \
      "$HF_UI_PUBLIC_URL/api/files/presign" || true)"
    if [[ "$duplicate_status" == "409" ]]; then
      ok "duplicate direct upload without overwrite is rejected with HTTP 409"
    else
      fail "duplicate direct upload without overwrite returned HTTP ${duplicate_status:-000} instead of 409"
    fi
  else
    fail "presigned upload URL missing or not on public S3 domain"
  fi
fi

if [[ "$status" -eq 0 ]]; then
  log "phase5 HF UI checks passed"
else
  log "phase5 HF UI checks failed"
fi

exit "$status"
