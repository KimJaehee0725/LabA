#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_common_args "$@"
INCOMING_LABSTACK_BACKUP_POSTGRES="${LABSTACK_BACKUP_POSTGRES:-}"
INCOMING_LABSTACK_BACKUP_CORE_REDIS="${LABSTACK_BACKUP_CORE_REDIS:-}"
INCOMING_LABSTACK_BACKUP_AUTHENTIK="${LABSTACK_BACKUP_AUTHENTIK:-}"
INCOMING_LABSTACK_BACKUP_EDGE_METADATA="${LABSTACK_BACKUP_EDGE_METADATA:-}"
INCOMING_LABSTACK_BACKUP_SHARED_MINIO="${LABSTACK_BACKUP_SHARED_MINIO:-}"
INCOMING_LABSTACK_BACKUP_HULY="${LABSTACK_BACKUP_HULY:-}"
INCOMING_LABSTACK_BACKUP_OVERLEAF="${LABSTACK_BACKUP_OVERLEAF:-}"
INCOMING_LABSTACK_BACKUP_LEGACY_GITEA="${LABSTACK_BACKUP_LEGACY_GITEA:-}"
INCOMING_LABSTACK_BACKUP_LEGACY_NEXTCLOUD="${LABSTACK_BACKUP_LEGACY_NEXTCLOUD:-}"
INCOMING_LABSTACK_BACKUP_LEGACY_MINIO="${LABSTACK_BACKUP_LEGACY_MINIO:-}"
INCOMING_PHASE7_ALLOW_HULY_STOP="${PHASE7_ALLOW_HULY_STOP:-}"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/30-huly.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/45-hf-ui.env" \
  "$ENV_DIR/70-overleaf.env" \
  "$ENV_DIR/90-backup.env"

LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
BACKUP_ARCHIVE_ROOT="${BACKUP_ROOT:-${LAB_BACKUP_ROOT}/archive}"
BACKUP_RUN_ID="${BACKUP_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
BACKUP_RUN_ROOT="${BACKUP_RUN_ROOT:-${BACKUP_ARCHIVE_ROOT}/phase7/$(date -u +%F)/${BACKUP_RUN_ID}}"
MANIFEST_FILE="$BACKUP_RUN_ROOT/manifest.tsv"

LABSTACK_BACKUP_POSTGRES="${LABSTACK_BACKUP_POSTGRES:-true}"
LABSTACK_BACKUP_CORE_REDIS="${LABSTACK_BACKUP_CORE_REDIS:-true}"
LABSTACK_BACKUP_AUTHENTIK="${LABSTACK_BACKUP_AUTHENTIK:-true}"
LABSTACK_BACKUP_EDGE_METADATA="${LABSTACK_BACKUP_EDGE_METADATA:-true}"
LABSTACK_BACKUP_SHARED_MINIO="${LABSTACK_BACKUP_SHARED_MINIO:-true}"
LABSTACK_BACKUP_HULY="${LABSTACK_BACKUP_HULY:-true}"
LABSTACK_BACKUP_OVERLEAF="${LABSTACK_BACKUP_OVERLEAF:-true}"
LABSTACK_BACKUP_LEGACY_GITEA="${LABSTACK_BACKUP_LEGACY_GITEA:-false}"
LABSTACK_BACKUP_LEGACY_NEXTCLOUD="${LABSTACK_BACKUP_LEGACY_NEXTCLOUD:-false}"
LABSTACK_BACKUP_LEGACY_MINIO="${LABSTACK_BACKUP_LEGACY_MINIO:-false}"

[[ -n "$INCOMING_LABSTACK_BACKUP_POSTGRES" ]] && LABSTACK_BACKUP_POSTGRES="$INCOMING_LABSTACK_BACKUP_POSTGRES"
[[ -n "$INCOMING_LABSTACK_BACKUP_CORE_REDIS" ]] && LABSTACK_BACKUP_CORE_REDIS="$INCOMING_LABSTACK_BACKUP_CORE_REDIS"
[[ -n "$INCOMING_LABSTACK_BACKUP_AUTHENTIK" ]] && LABSTACK_BACKUP_AUTHENTIK="$INCOMING_LABSTACK_BACKUP_AUTHENTIK"
[[ -n "$INCOMING_LABSTACK_BACKUP_EDGE_METADATA" ]] && LABSTACK_BACKUP_EDGE_METADATA="$INCOMING_LABSTACK_BACKUP_EDGE_METADATA"
[[ -n "$INCOMING_LABSTACK_BACKUP_SHARED_MINIO" ]] && LABSTACK_BACKUP_SHARED_MINIO="$INCOMING_LABSTACK_BACKUP_SHARED_MINIO"
[[ -n "$INCOMING_LABSTACK_BACKUP_HULY" ]] && LABSTACK_BACKUP_HULY="$INCOMING_LABSTACK_BACKUP_HULY"
[[ -n "$INCOMING_LABSTACK_BACKUP_OVERLEAF" ]] && LABSTACK_BACKUP_OVERLEAF="$INCOMING_LABSTACK_BACKUP_OVERLEAF"
[[ -n "$INCOMING_LABSTACK_BACKUP_LEGACY_GITEA" ]] && LABSTACK_BACKUP_LEGACY_GITEA="$INCOMING_LABSTACK_BACKUP_LEGACY_GITEA"
[[ -n "$INCOMING_LABSTACK_BACKUP_LEGACY_NEXTCLOUD" ]] && LABSTACK_BACKUP_LEGACY_NEXTCLOUD="$INCOMING_LABSTACK_BACKUP_LEGACY_NEXTCLOUD"
[[ -n "$INCOMING_LABSTACK_BACKUP_LEGACY_MINIO" ]] && LABSTACK_BACKUP_LEGACY_MINIO="$INCOMING_LABSTACK_BACKUP_LEGACY_MINIO"

MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_STORAGE_BUCKET_MODELS="${MINIO_STORAGE_BUCKET_MODELS:-lab-models}"
MINIO_STORAGE_BUCKET_DATASETS="${MINIO_STORAGE_BUCKET_DATASETS:-lab-datasets}"
MINIO_STORAGE_BUCKET_ARTIFACTS="${MINIO_STORAGE_BUCKET_ARTIFACTS:-lab-artifacts}"
MINIO_STORAGE_BUCKET_PUBLIC="${MINIO_STORAGE_BUCKET_PUBLIC:-lab-public}"
MINIO_STORAGE_BUCKET_BACKUPS="${MINIO_STORAGE_BUCKET_BACKUPS:-lab-backups}"
MINIO_STORAGE_BUCKETS="${MINIO_STORAGE_BUCKETS:-${MINIO_STORAGE_BUCKET_MODELS},${MINIO_STORAGE_BUCKET_DATASETS},${MINIO_STORAGE_BUCKET_ARTIFACTS},${MINIO_STORAGE_BUCKET_PUBLIC},${MINIO_STORAGE_BUCKET_BACKUPS}}"

HULY_COMPOSE_FILE="${HULY_COMPOSE_FILE:-${LAB_STACK_ROOT}/compose/huly/docker-compose.yml}"
PHASE7_ALLOW_HULY_STOP="${PHASE7_ALLOW_HULY_STOP:-false}"
[[ -n "$INCOMING_PHASE7_ALLOW_HULY_STOP" ]] && PHASE7_ALLOW_HULY_STOP="$INCOMING_PHASE7_ALLOW_HULY_STOP"

status=0
stopped_huly_containers=()

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

record_failure() {
  log "fail: $*"
  status=1
}

require_secret_value() {
  local name="$1"
  local value="${!name:-}"
  if is_dry_run; then
    return 0
  fi
  if is_placeholder "$value"; then
    die "$name must be set in $ENV_DIR before running active backups"
  fi
}

manifest_path() {
  local path="$1"
  if [[ "$path" == "$BACKUP_RUN_ROOT"* ]]; then
    printf '%s' "${path#$BACKUP_RUN_ROOT/}"
  else
    printf '%s' "$path"
  fi
}

add_manifest() {
  local service="$1"
  local kind="$2"
  local path="$3"
  local notes="${4:-}"
  local size sha rel_path

  if is_dry_run; then
    printf '+ manifest %q %q %q %q\n' "$service" "$kind" "$path" "$notes"
    return 0
  fi

  if [[ -f "$path" ]]; then
    size="$(stat -c '%s' "$path")"
    sha="$(sha256sum "$path" | awk '{print $1}')"
  elif [[ -d "$path" ]]; then
    size="$(du -sb "$path" | awk '{print $1}')"
    sha="directory"
  else
    record_failure "missing backup artifact: $path"
    return 1
  fi

  rel_path="$(manifest_path "$path")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$service" "$kind" "$rel_path" "$size" "$sha" "$notes" >>"$MANIFEST_FILE"
}

run_mc() {
  if is_dry_run; then
    printf '+ docker run --rm --network %q -v %q:/backup -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc' \
      "$LABSTACK_DATA_NETWORK" "$BACKUP_RUN_ROOT/minio" "$MINIO_MC_IMAGE"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$BACKUP_RUN_ROOT/minio:/backup" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

restart_stopped_huly() {
  if ((${#stopped_huly_containers[@]} == 0)); then
    return 0
  fi
  log "restarting stopped Huly containers"
  docker start "${stopped_huly_containers[@]}" >/dev/null || true
  stopped_huly_containers=()
}

trap restart_stopped_huly EXIT

stop_huly_for_cold_backup() {
  local container state
  local huly_containers=(
    huly-front
    huly-account
    huly-workspace
    huly-transactor
    huly-collaborator
    huly-fulltext
    huly-stats
    huly-kvs
    huly-rekoni
    huly-github
    huly-calendar
    huly-mongodb
    huly-redpanda
    huly-minio
    huly-elastic
    huly-cockroach
  )

  if ! is_true "$PHASE7_ALLOW_HULY_STOP"; then
    die "Huly cold backup requires PHASE7_ALLOW_HULY_STOP=true; set LABSTACK_BACKUP_HULY=false to skip Huly"
  fi

  for container in "${huly_containers[@]}"; do
    if ! docker inspect "$container" >/dev/null 2>&1; then
      continue
    fi
    state="$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || true)"
    if [[ "$state" == "running" ]]; then
      docker stop "$container" >/dev/null
      stopped_huly_containers+=("$container")
    fi
  done
}

write_manifest_header() {
  if is_dry_run; then
    log "dry-run backup root: $BACKUP_RUN_ROOT"
    return 0
  fi
  install -d -m 0750 "$BACKUP_RUN_ROOT"
  {
    printf '# lab-stack backup manifest v1\n'
    printf '# created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '# backup_run_root=%s\n' "$BACKUP_RUN_ROOT"
    printf 'service\tkind\tpath\tsize_bytes\tsha256\tnotes\n'
  } >"$MANIFEST_FILE"
}

backup_postgres() {
  is_true "$LABSTACK_BACKUP_POSTGRES" || return 0
  log "backing up active Postgres databases"
  local db out
  local dbs="${PHASE7_POSTGRES_DBS:-${AUTHENTIK_POSTGRES_DB:-authentik},${POSTGRES_DB:-postgres}}"
  split_csv "$dbs"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/postgres"
  for db in "${SPLIT_RESULT[@]}"; do
    out="$BACKUP_RUN_ROOT/postgres/${db}.dump"
    if is_dry_run; then
      printf '+ docker exec postgres pg_dump -U %q -Fc %q > %q\n' "${POSTGRES_USER:-postgres}" "$db" "$out"
    else
      if docker exec postgres pg_dump -U "${POSTGRES_USER:-postgres}" -Fc "$db" >"$out"; then
        test -s "$out"
        add_manifest postgres postgres-dump "$out" "database=$db"
      else
        record_failure "Postgres dump failed for database $db"
      fi
    fi
  done
}

backup_core_redis() {
  is_true "$LABSTACK_BACKUP_CORE_REDIS" || return 0
  log "backing up active core Redis RDB"
  require_secret_value REDIS_PASSWORD
  local out="$BACKUP_RUN_ROOT/redis/core-redis.rdb"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/redis"
  if is_dry_run; then
    printf '+ docker exec redis redis-cli --rdb /tmp/core-redis.rdb && docker cp redis:/tmp/core-redis.rdb %q\n' "$out"
    return 0
  fi
  if docker exec -e "REDIS_PASSWORD=${REDIS_PASSWORD}" redis sh -lc 'redis-cli -a "$REDIS_PASSWORD" --no-auth-warning --rdb /tmp/core-redis.rdb >/dev/null' &&
    docker cp redis:/tmp/core-redis.rdb "$out" &&
    docker exec redis rm -f /tmp/core-redis.rdb; then
    test -s "$out"
    add_manifest redis rdb "$out" "container=redis"
  else
    record_failure "core Redis RDB backup failed"
  fi
}

backup_authentik_files() {
  is_true "$LABSTACK_BACKUP_AUTHENTIK" || return 0
  log "backing up Authentik file data"
  local out="$BACKUP_RUN_ROOT/authentik/authentik-data.tar.gz"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/authentik"
  if is_dry_run; then
    printf '+ tar -C %q -czf %q authentik\n' "$LAB_STACK_ROOT/data" "$out"
    return 0
  fi
  if [[ -d "$LAB_STACK_ROOT/data/authentik" ]] &&
    tar -C "$LAB_STACK_ROOT/data" -czf "$out" authentik; then
    add_manifest authentik files-archive "$out" "data=media,certs,templates"
  else
    record_failure "Authentik file archive failed"
  fi
}

backup_edge_metadata() {
  is_true "$LABSTACK_BACKUP_EDGE_METADATA" || return 0
  log "recording edge/env/certificate metadata"
  local meta="$BACKUP_RUN_ROOT/edge/metadata.txt"
  local nginx_archive="$BACKUP_RUN_ROOT/edge/nginx-config.tar.gz"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/edge"
  if is_dry_run; then
    printf '+ write redacted metadata to %q\n' "$meta"
    printf '+ tar -C %q -czf %q nginx\n' "$LAB_STACK_ROOT" "$nginx_archive"
    return 0
  fi
  {
    printf 'created_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'lab_stack_root=%s\n' "$LAB_STACK_ROOT"
    printf '\n[env-files]\n'
    find "$ENV_DIR" -maxdepth 1 -type f -name '*.env' -printf '%M\t%u:%g\t%p\n' 2>/dev/null | sort || true
    printf '\n[cert-files]\n'
    find "$LAB_STACK_ROOT/certs" -maxdepth 2 -type f -printf '%M\t%u:%g\t%p\n' 2>/dev/null | sort || true
    printf '\n[docker-containers]\n'
    docker ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}' | sort
  } >"$meta"
  add_manifest edge metadata "$meta" "redacted values only"
  if [[ -d "$LAB_STACK_ROOT/nginx" ]] &&
    tar -C "$LAB_STACK_ROOT" -czf "$nginx_archive" nginx; then
    add_manifest edge nginx-config "$nginx_archive" "public config"
  else
    record_failure "Nginx config archive failed"
  fi
}

backup_shared_minio() {
  is_true "$LABSTACK_BACKUP_SHARED_MINIO" || return 0
  log "backing up shared MinIO storage buckets"
  require_secret_value MINIO_ROOT_USER
  require_secret_value MINIO_ROOT_PASSWORD
  local bucket
  local archive="$BACKUP_RUN_ROOT/minio/shared-minio-buckets.tar.gz"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/minio/mirror"
  split_csv "$MINIO_STORAGE_BUCKETS"
  for bucket in "${SPLIT_RESULT[@]}"; do
    run_mc mirror --overwrite "$MINIO_ALIAS/$bucket" "/backup/mirror/$bucket"
  done
  if is_dry_run; then
    printf '+ tar -C %q -czf %q mirror\n' "$BACKUP_RUN_ROOT/minio" "$archive"
    return 0
  fi
  if tar -C "$BACKUP_RUN_ROOT/minio" -czf "$archive" mirror; then
    add_manifest minio buckets-archive "$archive" "buckets=$MINIO_STORAGE_BUCKETS"
  else
    record_failure "shared MinIO archive failed"
  fi
}

backup_huly_cold() {
  is_true "$LABSTACK_BACKUP_HULY" || return 0
  log "backing up Huly data with cold maintenance stop"
  local out="$BACKUP_RUN_ROOT/huly/huly-data-cold.tar.gz"
  run_cmd install -d -m 0750 "$BACKUP_RUN_ROOT/huly"
  if is_dry_run; then
    printf '+ PHASE7_ALLOW_HULY_STOP=true docker stop huly-* && tar -C %q -czf %q huly && docker start huly-*\n' "$LAB_STACK_ROOT/data" "$out"
    return 0
  fi
  [[ -f "$HULY_COMPOSE_FILE" ]] || die "missing Huly compose file: $HULY_COMPOSE_FILE"
  stop_huly_for_cold_backup
  if [[ -d "$LAB_STACK_ROOT/data/huly" ]] &&
    tar -C "$LAB_STACK_ROOT/data" -czf "$out" huly; then
    add_manifest huly cold-data-archive "$out" "maintenance-stop=true"
  else
    record_failure "Huly cold data archive failed"
  fi
  restart_stopped_huly
}

backup_overleaf() {
  is_true "$LABSTACK_BACKUP_OVERLEAF" || return 0
  log "backing up Overleaf Mongo, Redis, and project files"
  local root="$BACKUP_RUN_ROOT/overleaf"
  if is_dry_run; then
    printf '+ OVERLEAF_BACKUP_ROOT=%q %q --dry-run\n' "$root" "$SCRIPT_DIR/95-backup-overleaf.sh"
    return 0
  fi
  if OVERLEAF_BACKUP_ROOT="$root" "$SCRIPT_DIR/95-backup-overleaf.sh"; then
    add_manifest overleaf mongo-archive "$root/mongo/overleaf.archive" "database=${OVERLEAF_MONGO_DB:-sharelatex}"
    add_manifest overleaf files-archive "$root/files/overleaf-files.tar.gz" "projects"
    add_manifest overleaf redis-archive "$root/redis/overleaf-redis.tar.gz" "redis data"
  else
    record_failure "Overleaf backup failed"
  fi
}

backup_legacy_modules() {
  if is_true "$LABSTACK_BACKUP_LEGACY_MINIO"; then
    BACKUP_ROOT="$BACKUP_RUN_ROOT/legacy" "$SCRIPT_DIR/92-backup-minio.sh"
  fi
  if is_true "$LABSTACK_BACKUP_LEGACY_GITEA"; then
    BACKUP_ROOT="$BACKUP_RUN_ROOT/legacy" "$SCRIPT_DIR/93-backup-gitea.sh"
  fi
  if is_true "$LABSTACK_BACKUP_LEGACY_NEXTCLOUD"; then
    BACKUP_ROOT="$BACKUP_RUN_ROOT/legacy" "$SCRIPT_DIR/94-backup-nextcloud.sh"
  fi
}

write_manifest_header
backup_postgres
backup_core_redis
backup_authentik_files
backup_edge_metadata
backup_shared_minio
backup_huly_cold
backup_overleaf
backup_legacy_modules

if ! is_dry_run; then
  add_manifest phase7 manifest "$MANIFEST_FILE" "backup manifest"
fi

if [[ "$status" -eq 0 ]]; then
  log "active backup completed: $BACKUP_RUN_ROOT"
else
  log "active backup completed with failures: $BACKUP_RUN_ROOT"
fi

exit "$status"
