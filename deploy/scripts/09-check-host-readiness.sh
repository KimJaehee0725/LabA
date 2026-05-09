#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
. "$COMMON_DIR/common.sh"

parse_common_args "$@"
load_env_file "$ENV_DIR/00-global.env"

status=0

planned_check() {
  log "dry-run check: $*"
}

check_cmd() {
  local name="$1"
  local cmd="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    log "ok: $name"
  else
    log "missing: $name ($cmd)"
    status=1
  fi
}

check_path() {
  local path="$1"

  if [[ -d "$path" ]]; then
    log "ok: directory exists: $path"
  else
    log "missing: directory: $path"
    status=1
    return
  fi

  if [[ -w "$path" ]]; then
    log "ok: directory writable: $path"
  else
    log "not writable: $path"
    status=1
  fi
}

check_mount() {
  local path="$1"

  if findmnt "$path" >/dev/null 2>&1; then
    log "ok: mount exists: $path"
  else
    log "missing: mount: $path"
    status=1
    return
  fi

  if [[ -w "$path" ]]; then
    log "ok: mount writable: $path"
  else
    log "not writable: mount: $path"
    status=1
  fi
}

check_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    log "ok: docker compose plugin"
  else
    log "missing: docker compose plugin"
    status=1
  fi
}

check_network() {
  local name="$1"

  if docker network inspect "$name" >/dev/null 2>&1; then
    log "ok: docker network exists: $name"
  else
    log "missing: docker network: $name"
    status=1
  fi
}

if is_dry_run; then
  log "dry-run: host readiness checks that would be performed"
  planned_check "command exists: docker"
  planned_check "command exists: findmnt"
  planned_check "docker compose plugin"
  planned_check "docker network exists: ${LABSTACK_PUBLIC_NETWORK:-labstack_public}"
  planned_check "docker network exists: ${LABSTACK_BACKEND_NETWORK:-labstack_backend}"
  planned_check "docker network exists: ${LABSTACK_DATA_NETWORK:-labstack_data}"
  planned_check "directory exists and writable: $LAB_STACK_ROOT"
  planned_check "mount exists and writable: ${LAB_MINIO_DATA_ROOT:-/mnt/hdd/minio}"
  planned_check "mount exists and writable: ${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
  exit 0
fi

check_cmd docker docker
check_cmd findmnt findmnt

if command -v docker >/dev/null 2>&1; then
  check_docker_compose
  check_network "${LABSTACK_PUBLIC_NETWORK:-labstack_public}"
  check_network "${LABSTACK_BACKEND_NETWORK:-labstack_backend}"
  check_network "${LABSTACK_DATA_NETWORK:-labstack_data}"
fi

check_path "$LAB_STACK_ROOT"

if command -v findmnt >/dev/null 2>&1; then
  check_mount "${LAB_MINIO_DATA_ROOT:-/mnt/hdd/minio}"
  check_mount "${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
fi

exit "$status"
