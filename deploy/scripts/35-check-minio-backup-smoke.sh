#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/35-minio-storage.env"

LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_STORAGE_BUCKET_BACKUPS="${MINIO_STORAGE_BUCKET_BACKUPS:-lab-backups}"
MINIO_BACKUP_SMOKE_BUCKET="${MINIO_BACKUP_SMOKE_BUCKET:-$MINIO_STORAGE_BUCKET_BACKUPS}"
MINIO_BACKUP_SMOKE_PREFIX="${MINIO_BACKUP_SMOKE_PREFIX:-smoke/phase4-backup}"
MINIO_BACKUP_SMOKE_ROOT="${MINIO_BACKUP_SMOKE_ROOT:-${LAB_BACKUP_ROOT}/minio-smoke}"

status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" ||
    "$value" == change-me* ||
    "$value" == CHANGE-ME* ||
    "$value" == todo* ||
    "$value" == TODO* ]]
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

run_mc() {
  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$work_dir:/work:ro" \
    -v "$MINIO_BACKUP_SMOKE_ROOT:/backup" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

require_cmd docker
require_cmd awk
require_cmd sha256sum
require_cmd stat

require_runtime_secret MINIO_ROOT_USER
require_runtime_secret MINIO_ROOT_PASSWORD

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
mkdir -p "$MINIO_BACKUP_SMOKE_ROOT/$MINIO_BACKUP_SMOKE_BUCKET/${MINIO_BACKUP_SMOKE_PREFIX%/}"

smoke_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
sample_name="sample-${smoke_id}.txt"
object_key="${MINIO_BACKUP_SMOKE_PREFIX%/}/$sample_name"
sample_file="$work_dir/$sample_name"
mirrored_file="$MINIO_BACKUP_SMOKE_ROOT/$MINIO_BACKUP_SMOKE_BUCKET/${MINIO_BACKUP_SMOKE_PREFIX%/}/$sample_name"

printf 'phase4 minio backup smoke %s\n' "$smoke_id" >"$sample_file"

if run_mc mb --ignore-existing "$MINIO_ALIAS/$MINIO_BACKUP_SMOKE_BUCKET" >/dev/null &&
  run_mc cp "/work/$sample_name" "$MINIO_ALIAS/$MINIO_BACKUP_SMOKE_BUCKET/$object_key" >/dev/null &&
  run_mc stat "$MINIO_ALIAS/$MINIO_BACKUP_SMOKE_BUCKET/$object_key" >/dev/null; then
  ok "backup smoke source object is present"
else
  fail "backup smoke source object could not be created"
fi

if run_mc mirror --overwrite "$MINIO_ALIAS/$MINIO_BACKUP_SMOKE_BUCKET/${MINIO_BACKUP_SMOKE_PREFIX%/}" "/backup/$MINIO_BACKUP_SMOKE_BUCKET/${MINIO_BACKUP_SMOKE_PREFIX%/}" >/dev/null; then
  ok "backup smoke mirror completed"
else
  fail "backup smoke mirror failed"
fi

if [[ -f "$mirrored_file" ]]; then
  ok "mirrored file exists: $mirrored_file"
else
  fail "missing mirrored file: $mirrored_file"
fi

if [[ -f "$mirrored_file" ]]; then
  source_size="$(stat -c '%s' "$sample_file")"
  mirror_size="$(stat -c '%s' "$mirrored_file")"
  source_hash="$(sha256sum "$sample_file" | awk '{print $1}')"
  mirror_hash="$(sha256sum "$mirrored_file" | awk '{print $1}')"
  if [[ "$source_size" == "$mirror_size" && "$source_hash" == "$mirror_hash" ]]; then
    ok "backup smoke checksum and size match"
  else
    fail "backup smoke mismatch: source size/hash ${source_size}/${source_hash}, mirrored ${mirror_size}/${mirror_hash}"
  fi
fi

if [[ "$status" -eq 0 ]]; then
  log "phase4 MinIO backup smoke checks passed"
else
  log "phase4 MinIO backup smoke checks failed"
fi

exit "$status"
