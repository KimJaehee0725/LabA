#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_PLATFORM_ROOT="${LAB_PLATFORM_ROOT:-/srv/lab-platform}"
ENV_DIR="${ENV_DIR:-${LAB_PLATFORM_ROOT}/env}"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

load_env_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$file"
    set +a
  fi
}

load_envs() {
  local file
  for file in "$@"; do
    load_env_file "$file"
  done
}

run_cmd() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    printf '+ %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

compose_config() {
  local compose_file="$1"
  shift
  docker compose "$@" -f "$compose_file" config >/dev/null
}
