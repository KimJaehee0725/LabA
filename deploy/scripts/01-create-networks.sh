#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
. "$COMMON_DIR/common.sh"

parse_common_args "$@"
load_env_file "$ENV_DIR/00-global.env"

if ! is_dry_run; then
  require_cmd docker
fi

create_network() {
  local name="$1"
  if is_dry_run; then
    run_cmd docker network create "$name"
    return 0
  fi

  if docker network inspect "$name" >/dev/null 2>&1; then
    echo "network exists: $name"
    return 0
  fi
  run_cmd docker network create "$name"
}

create_network "${LABSTACK_PUBLIC_NETWORK:-labstack_public}"
create_network "${LABSTACK_BACKEND_NETWORK:-labstack_backend}"
create_network "${LABSTACK_DATA_NETWORK:-labstack_data}"
