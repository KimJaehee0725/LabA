#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"

create_network() {
  local name="$1"
  if docker network inspect "$name" >/dev/null 2>&1; then
    echo "network exists: $name"
    return 0
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "+ docker network create $name"
  else
    docker network create "$name"
  fi
}

create_network lab_public
create_network lab_backend
create_network lab_data
