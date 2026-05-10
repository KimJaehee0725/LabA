#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_STACK_ROOT="${LAB_STACK_ROOT:-/opt/lab-stack}"
ENV_DIR="${ENV_DIR:-${LAB_STACK_ROOT}/env}"
DRY_RUN="${DRY_RUN:-false}"
LABSTACK_PUBLIC_NETWORK="${LABSTACK_PUBLIC_NETWORK:-labstack_public}"
LABSTACK_BACKEND_NETWORK="${LABSTACK_BACKEND_NETWORK:-labstack_backend}"
LABSTACK_DATA_NETWORK="${LABSTACK_DATA_NETWORK:-labstack_data}"

export LAB_STACK_ROOT ENV_DIR
export LABSTACK_PUBLIC_NETWORK LABSTACK_BACKEND_NETWORK LABSTACK_DATA_NETWORK

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
  if is_dry_run; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

is_dry_run() {
  [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]
}

parse_common_args() {
  while (($#)); do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
    shift
  done
}

print_usage() {
  cat <<USAGE
Usage: ${0##*/} [--dry-run]
USAGE
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

compose_config() {
  local compose_file="$1"
  shift
  docker compose "$@" -f "$compose_file" config >/dev/null
}
