#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BACKUP_RUN_ROOT=""
while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --backup-root)
      shift
      BACKUP_RUN_ROOT="${1:-}"
      [[ -n "$BACKUP_RUN_ROOT" ]] || die "--backup-root requires a value"
      ;;
    -h|--help)
      cat <<USAGE
Usage: ${0##*/} [--dry-run] [--backup-root PATH]
USAGE
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

INCOMING_PHASE7_RESTORE_MINIO_WRITE="${PHASE7_RESTORE_MINIO_WRITE:-}"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/70-overleaf.env" \
  "$ENV_DIR/90-backup.env"

LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
BACKUP_ARCHIVE_ROOT="${BACKUP_ROOT:-${LAB_BACKUP_ROOT}/archive}"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
PHASE7_RESTORE_MINIO_WRITE="${PHASE7_RESTORE_MINIO_WRITE:-true}"
[[ -n "$INCOMING_PHASE7_RESTORE_MINIO_WRITE" ]] && PHASE7_RESTORE_MINIO_WRITE="$INCOMING_PHASE7_RESTORE_MINIO_WRITE"

status=0
temp_db=""
temp_dir=""
temp_bucket="phase7-restore-rehearsal-$(date -u +%Y%m%d%H%M%S)"
temp_bucket_created=false

is_true() {
  [[ "${1:-}" == "true" || "${1:-}" == "1" || "${1:-}" == "yes" ]]
}

find_latest_backup_root() {
  find "$BACKUP_ARCHIVE_ROOT/phase7" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | tail -n 1
}

if [[ -z "$BACKUP_RUN_ROOT" ]]; then
  BACKUP_RUN_ROOT="$(find_latest_backup_root || true)"
fi
[[ -n "$BACKUP_RUN_ROOT" ]] || die "no Phase 7 backup root found under $BACKUP_ARCHIVE_ROOT/phase7"

MANIFEST_FILE="$BACKUP_RUN_ROOT/manifest.tsv"
RESTORE_REPORT="$BACKUP_RUN_ROOT/restore-rehearsal.tsv"

artifact_path() {
  local rel="$1"
  if [[ "$rel" = /* ]]; then
    printf '%s' "$rel"
  else
    printf '%s/%s' "$BACKUP_RUN_ROOT" "$rel"
  fi
}

find_artifact() {
  local service="$1"
  local kind="$2"
  if is_dry_run && [[ ! -f "$MANIFEST_FILE" ]]; then
    case "$service:$kind" in
      postgres:postgres-dump) printf 'postgres/authentik.dump\n' ;;
      minio:buckets-archive) printf 'minio/shared-minio-buckets.tar.gz\n' ;;
      huly:cold-data-archive) printf 'huly/huly-data-cold.tar.gz\n' ;;
      overleaf:mongo-archive) printf 'overleaf/mongo/overleaf.archive\n' ;;
    esac
    return 0
  fi
  awk -F '\t' -v service="$service" -v kind="$kind" \
    '$1 == service && $2 == kind {print $3; exit}' "$MANIFEST_FILE"
}

record_result() {
  local check="$1"
  local result="$2"
  local artifact="${3:-}"
  local notes="${4:-}"
  if is_dry_run; then
    printf '+ restore-result %q %q %q %q\n' "$check" "$result" "$artifact" "$notes"
    return 0
  fi
  printf '%s\t%s\t%s\t%s\n' "$check" "$result" "$artifact" "$notes" >>"$RESTORE_REPORT"
}

record_failure() {
  log "fail: $*"
  status=1
}

cleanup() {
  if [[ -n "$temp_db" ]]; then
    docker exec postgres dropdb -U "${POSTGRES_USER:-postgres}" --if-exists "$temp_db" >/dev/null 2>&1 || true
  fi
  if [[ "$temp_bucket_created" == "true" && -n "$temp_dir" && -d "$temp_dir" ]]; then
    run_mc rb --force "$MINIO_ALIAS/$temp_bucket" >/dev/null 2>&1 || true
  fi
  if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
    rm -rf "$temp_dir"
  fi
}
trap cleanup EXIT

run_mc() {
  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$temp_dir:/restore:ro" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

restore_postgres_rehearsal() {
  local rel artifact
  rel="$(find_artifact postgres postgres-dump || true)"
  [[ -n "$rel" ]] || { record_failure "missing Postgres dump artifact"; record_result postgres fail "" "missing artifact"; return; }
  artifact="$(artifact_path "$rel")"
  if is_dry_run; then
    printf '+ createdb temporary restore DB and pg_restore --list/--clean from %q\n' "$artifact"
    record_result postgres dry-run "$rel" "temporary DB restore"
    return
  fi
  [[ -s "$artifact" ]] || { record_failure "Postgres artifact is empty: $artifact"; record_result postgres fail "$rel" "empty artifact"; return; }
  temp_db="phase7_restore_$(date -u +%Y%m%d%H%M%S)"
  if docker exec postgres createdb -U "${POSTGRES_USER:-postgres}" "$temp_db" &&
    docker exec -i postgres pg_restore -U "${POSTGRES_USER:-postgres}" -d "$temp_db" --no-owner <"$artifact" >/dev/null &&
    docker exec postgres dropdb -U "${POSTGRES_USER:-postgres}" "$temp_db"; then
    temp_db=""
    record_result postgres pass "$rel" "temporary DB restore succeeded"
  else
    record_failure "Postgres restore rehearsal failed"
    record_result postgres fail "$rel" "temporary DB restore failed"
  fi
}

restore_minio_rehearsal() {
  local rel artifact
  rel="$(find_artifact minio buckets-archive || true)"
  [[ -n "$rel" ]] || { record_failure "missing MinIO buckets archive"; record_result minio fail "" "missing artifact"; return; }
  artifact="$(artifact_path "$rel")"
  if is_dry_run; then
    printf '+ tar -tzf %q and mirror into temporary MinIO bucket %q\n' "$artifact" "$temp_bucket"
    record_result minio dry-run "$rel" "temporary bucket mirror"
    return
  fi
  [[ -s "$artifact" ]] || { record_failure "MinIO artifact is empty: $artifact"; record_result minio fail "$rel" "empty artifact"; return; }
  temp_dir="$(mktemp -d)"
  if ! tar -C "$temp_dir" -xzf "$artifact"; then
    record_failure "MinIO archive extraction failed"
    record_result minio fail "$rel" "tar extraction failed"
    return
  fi
  if ! is_true "$PHASE7_RESTORE_MINIO_WRITE"; then
    find "$temp_dir" -type f | head -n 20 >/dev/null
    record_result minio pass "$rel" "archive listing only; PHASE7_RESTORE_MINIO_WRITE=$PHASE7_RESTORE_MINIO_WRITE"
    return
  fi
  if run_mc mb --ignore-existing "$MINIO_ALIAS/$temp_bucket" >/dev/null; then
    temp_bucket_created=true
  else
    record_failure "MinIO temporary bucket creation failed"
    record_result minio fail "$rel" "temporary bucket creation failed"
    return
  fi
  if
    run_mc mirror --overwrite /restore/mirror "$MINIO_ALIAS/$temp_bucket" >/dev/null &&
    run_mc ls --recursive "$MINIO_ALIAS/$temp_bucket" >/dev/null &&
    run_mc rb --force "$MINIO_ALIAS/$temp_bucket" >/dev/null; then
    temp_bucket_created=false
    record_result minio pass "$rel" "temporary bucket mirror succeeded and was removed"
  else
    record_failure "MinIO temporary bucket restore rehearsal failed"
    record_result minio fail "$rel" "temporary bucket mirror failed"
  fi
}

restore_huly_rehearsal() {
  local rel artifact
  rel="$(find_artifact huly cold-data-archive || true)"
  [[ -n "$rel" ]] || { record_failure "missing Huly cold archive"; record_result huly fail "" "missing artifact"; return; }
  artifact="$(artifact_path "$rel")"
  if is_dry_run; then
    printf '+ tar -tzf %q\n' "$artifact"
    record_result huly dry-run "$rel" "archive listing"
    return
  fi
  if [[ -s "$artifact" ]] && tar -tzf "$artifact" >/dev/null; then
    record_result huly pass "$rel" "cold archive listing succeeded"
  else
    record_failure "Huly cold archive listing failed"
    record_result huly fail "$rel" "archive listing failed"
  fi
}

restore_overleaf_rehearsal() {
  local rel artifact tmp_name
  rel="$(find_artifact overleaf mongo-archive || true)"
  [[ -n "$rel" ]] || { record_failure "missing Overleaf Mongo archive"; record_result overleaf fail "" "missing artifact"; return; }
  artifact="$(artifact_path "$rel")"
  tmp_name="/tmp/phase7-overleaf-restore-$(date -u +%Y%m%d%H%M%S).archive"
  if is_dry_run; then
    printf '+ docker cp %q overleaf-mongo:%q && mongorestore --dryRun\n' "$artifact" "$tmp_name"
    record_result overleaf dry-run "$rel" "mongorestore dry-run"
    return
  fi
  if [[ -s "$artifact" ]] &&
    docker cp "$artifact" "overleaf-mongo:$tmp_name" &&
    docker exec overleaf-mongo mongorestore --archive="$tmp_name" --dryRun >/dev/null &&
    docker exec overleaf-mongo rm -f "$tmp_name"; then
    record_result overleaf pass "$rel" "mongorestore dry-run succeeded"
  else
    docker exec overleaf-mongo rm -f "$tmp_name" >/dev/null 2>&1 || true
    record_failure "Overleaf Mongo restore dry-run failed"
    record_result overleaf fail "$rel" "mongorestore dry-run failed"
  fi
}

if ! is_dry_run; then
  [[ -f "$MANIFEST_FILE" ]] || die "missing manifest: $MANIFEST_FILE"
  {
    printf '# lab-stack restore rehearsal v1\n'
    printf '# created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# backup_run_root=%s\n' "$BACKUP_RUN_ROOT"
    printf 'check\tresult\tartifact\tnotes\n'
  } >"$RESTORE_REPORT"
else
  log "dry-run restore rehearsal for $BACKUP_RUN_ROOT"
fi

restore_postgres_rehearsal
restore_minio_rehearsal
restore_huly_rehearsal
restore_overleaf_rehearsal

if [[ "$status" -eq 0 ]]; then
  log "restore rehearsal passed for $BACKUP_RUN_ROOT"
else
  log "restore rehearsal failed for $BACKUP_RUN_ROOT"
fi

exit "$status"
