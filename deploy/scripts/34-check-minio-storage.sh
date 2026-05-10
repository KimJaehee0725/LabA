#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PHASE4_REQUIRE_REAL_DOMAINS_INCOMING="${PHASE4_REQUIRE_REAL_DOMAINS:-}"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/35-minio-storage.env"

AUTH_DOMAIN="${AUTH_DOMAIN:-auth.lab.example.ac.kr}"
FILES_DOMAIN="${FILES_DOMAIN:-files.lab.example.ac.kr}"
S3_DOMAIN="${S3_DOMAIN:-s3.lab.example.ac.kr}"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_STORAGE_BUCKET_MODELS="${MINIO_STORAGE_BUCKET_MODELS:-lab-models}"
MINIO_STORAGE_BUCKET_DATASETS="${MINIO_STORAGE_BUCKET_DATASETS:-lab-datasets}"
MINIO_STORAGE_BUCKET_ARTIFACTS="${MINIO_STORAGE_BUCKET_ARTIFACTS:-lab-artifacts}"
MINIO_STORAGE_BUCKET_PUBLIC="${MINIO_STORAGE_BUCKET_PUBLIC:-lab-public}"
MINIO_STORAGE_BUCKET_BACKUPS="${MINIO_STORAGE_BUCKET_BACKUPS:-lab-backups}"
MINIO_STORAGE_BUCKETS="${MINIO_STORAGE_BUCKETS:-${MINIO_STORAGE_BUCKET_MODELS},${MINIO_STORAGE_BUCKET_DATASETS},${MINIO_STORAGE_BUCKET_ARTIFACTS},${MINIO_STORAGE_BUCKET_PUBLIC},${MINIO_STORAGE_BUCKET_BACKUPS}}"
MINIO_STORAGE_VERSIONING_BUCKETS="${MINIO_STORAGE_VERSIONING_BUCKETS:-$MINIO_STORAGE_BUCKETS}"
MINIO_STORAGE_SMOKE_BUCKET="${MINIO_STORAGE_SMOKE_BUCKET:-$MINIO_STORAGE_BUCKET_ARTIFACTS}"
MINIO_STORAGE_SMOKE_PREFIX="${MINIO_STORAGE_SMOKE_PREFIX:-smoke/phase4}"
S3_URL="${S3_URL:-https://${S3_DOMAIN}}"
S3_URL="${S3_URL%/}"
PHASE4_REQUIRE_REAL_DOMAINS="${PHASE4_REQUIRE_REAL_DOMAINS:-true}"
if [[ -n "$PHASE4_REQUIRE_REAL_DOMAINS_INCOMING" ]]; then
  PHASE4_REQUIRE_REAL_DOMAINS="$PHASE4_REQUIRE_REAL_DOMAINS_INCOMING"
fi

status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

split_csv() {
  local value="$1"
  local item
  SPLIT_RESULT=()
  IFS=',' read -r -a _split_items <<<"$value"
  for item in "${_split_items[@]}"; do
    item="${item//[[:space:]]/}"
    [[ -n "$item" ]] || continue
    SPLIT_RESULT+=("$item")
  done
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
  elif is_true "$PHASE4_REQUIRE_REAL_DOMAINS" && is_example_value "$value"; then
    fail "$name still uses an example domain/value"
  else
    ok "$name is set"
  fi
}

require_runtime_secret() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set without printing its value"
  fi
}

check_non_placeholder() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set"
  fi
}

check_minio_oidc_redirect() {
  local expected="https://${FILES_DOMAIN}/oauth_callback"
  local redirect_found=false
  local redirect_uri
  IFS=',' read -r -a redirect_uris <<<"${MINIO_OIDC_REDIRECT_URIS:-}"
  for redirect_uri in "${redirect_uris[@]}"; do
    redirect_uri="${redirect_uri//[[:space:]]/}"
    if [[ "$redirect_uri" == "$expected" ]]; then
      redirect_found=true
      break
    fi
  done
  if [[ "$redirect_found" == "true" ]]; then
    ok "MINIO_OIDC_REDIRECT_URIS contains $expected"
  else
    fail "MINIO_OIDC_REDIRECT_URIS must contain $expected"
  fi
}

bucket_in_list() {
  local needle="$1"
  shift
  local bucket
  for bucket in "$@"; do
    [[ "$bucket" == "$needle" ]] && return 0
  done
  return 1
}

run_mc() {
  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$work_dir:/work" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
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

curl_resolve_args=()
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  IFS=',' read -r -a curl_resolve_values <<<"$CURL_RESOLVE"
  for curl_resolve in "${curl_resolve_values[@]}"; do
    curl_resolve="${curl_resolve//[[:space:]]/}"
    [[ -n "$curl_resolve" ]] || continue
    curl_resolve_args+=(--resolve "$curl_resolve")
  done
elif [[ "${STAGING_IP:-}" != "" ]]; then
  curl_resolve_args+=(--resolve "${S3_DOMAIN}:443:${STAGING_IP}")
  curl_resolve_args+=(--resolve "${FILES_DOMAIN}:443:${STAGING_IP}")
  curl_resolve_args+=(--resolve "${AUTH_DOMAIN}:443:${STAGING_IP}")
fi
curl_probe_args=(-ksS --noproxy "*" "${curl_resolve_args[@]}")

require_cmd docker
require_cmd curl
require_cmd cmp

check_real_value FILES_DOMAIN
check_real_value S3_DOMAIN
check_real_value AUTH_DOMAIN
require_runtime_secret MINIO_ROOT_USER
require_runtime_secret MINIO_ROOT_PASSWORD
check_non_placeholder MINIO_OIDC_CLIENT_ID
require_runtime_secret MINIO_OIDC_CLIENT_SECRET
check_minio_oidc_redirect
if [[ "${MINIO_IDENTITY_OPENID_CLAIM_NAME:-policy}" == "policy" ]]; then
  ok "MINIO_IDENTITY_OPENID_CLAIM_NAME is policy"
else
  fail "MINIO_IDENTITY_OPENID_CLAIM_NAME must be policy"
fi
if [[ ",${MINIO_IDENTITY_OPENID_SCOPES:-}," == *",policy,"* ]]; then
  ok "MINIO_IDENTITY_OPENID_SCOPES includes policy"
else
  fail "MINIO_IDENTITY_OPENID_SCOPES must include policy"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

split_csv "$MINIO_STORAGE_BUCKETS"
storage_buckets=("${SPLIT_RESULT[@]}")
split_csv "$MINIO_STORAGE_VERSIONING_BUCKETS"
versioning_buckets=("${SPLIT_RESULT[@]}")

if bucket_in_list "$MINIO_STORAGE_BUCKET_PUBLIC" "${storage_buckets[@]}"; then
  ok "public bucket is part of Phase 4 bucket set"
else
  fail "MINIO_STORAGE_BUCKET_PUBLIC must be included in MINIO_STORAGE_BUCKETS"
fi

if bucket_in_list "$MINIO_STORAGE_SMOKE_BUCKET" "${storage_buckets[@]}"; then
  ok "smoke bucket is part of Phase 4 bucket set"
else
  fail "MINIO_STORAGE_SMOKE_BUCKET must be included in MINIO_STORAGE_BUCKETS"
fi

check_container minio
check_no_host_ports minio

if docker exec minio curl -fsS http://localhost:9000/minio/health/live >/dev/null; then
  ok "MinIO health endpoint is live"
else
  fail "MinIO health endpoint is not live"
fi

for bucket in "${storage_buckets[@]}"; do
  if run_mc ls "$MINIO_ALIAS/$bucket" >/dev/null; then
    ok "bucket exists: $bucket"
  else
    fail "missing bucket: $bucket"
  fi
done

for bucket in "${versioning_buckets[@]}"; do
  if run_mc version info "$MINIO_ALIAS/$bucket" | grep -qi enabled; then
    ok "bucket versioning enabled: $bucket"
  else
    fail "bucket versioning is not enabled: $bucket"
  fi
done

smoke_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
private_key="${MINIO_STORAGE_SMOKE_PREFIX%/}/private-${smoke_id}.txt"
public_key="${MINIO_STORAGE_SMOKE_PREFIX%/}/public-${smoke_id}.txt"
printf 'phase4 private smoke %s\n' "$smoke_id" >"$work_dir/private.txt"
printf 'phase4 public smoke %s\n' "$smoke_id" >"$work_dir/public.txt"

if run_mc cp /work/private.txt "$MINIO_ALIAS/$MINIO_STORAGE_SMOKE_BUCKET/$private_key" >/dev/null &&
  run_mc stat "$MINIO_ALIAS/$MINIO_STORAGE_SMOKE_BUCKET/$private_key" >/dev/null &&
  run_mc cp "$MINIO_ALIAS/$MINIO_STORAGE_SMOKE_BUCKET/$private_key" /work/private-download.txt >/dev/null &&
  cmp -s "$work_dir/private.txt" "$work_dir/private-download.txt"; then
  ok "private bucket upload/stat/download smoke passed"
else
  fail "private bucket upload/stat/download smoke failed"
fi

private_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$S3_URL/$MINIO_STORAGE_SMOKE_BUCKET/$private_key" || true)"
if [[ "$private_status" == "401" || "$private_status" == "403" ]]; then
  ok "private bucket anonymous download denied with HTTP $private_status"
else
  fail "private bucket anonymous download returned HTTP ${private_status:-000}"
fi

if run_mc cp /work/public.txt "$MINIO_ALIAS/$MINIO_STORAGE_BUCKET_PUBLIC/$public_key" >/dev/null &&
  curl "${curl_probe_args[@]}" -f -o "$work_dir/public-download.txt" "$S3_URL/$MINIO_STORAGE_BUCKET_PUBLIC/$public_key" &&
  cmp -s "$work_dir/public.txt" "$work_dir/public-download.txt"; then
  ok "public bucket anonymous download smoke passed"
else
  fail "public bucket anonymous download smoke failed"
fi

if [[ "$status" -eq 0 ]]; then
  log "phase4 MinIO storage checks passed"
else
  log "phase4 MinIO storage checks failed"
fi

exit "$status"
