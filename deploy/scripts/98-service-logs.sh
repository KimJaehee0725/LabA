#!/usr/bin/env bash
set -euo pipefail

service="${1:-}"
if [[ -z "$service" ]]; then
  echo "usage: $0 <container-name>" >&2
  exit 2
fi

docker logs --tail "${TAIL:-200}" "$service"
