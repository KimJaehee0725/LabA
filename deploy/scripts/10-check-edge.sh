#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env"
require_cmd docker
require_cmd ss

docker exec nginx nginx -t

container_networks="$(docker inspect nginx --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}')"
for network in "$LABSTACK_PUBLIC_NETWORK" "$LABSTACK_BACKEND_NETWORK" "$LABSTACK_DATA_NETWORK"; do
  if ! printf '%s\n' "$container_networks" | grep -Fxq "$network"; then
    die "nginx is not attached to docker network: $network"
  fi
done

bad_port_pattern='^(2222|5432|6379|9000|9001|9980|3000|5000|8000)$'

ports="$(ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://')"
bad="$(printf '%s\n' "$ports" | grep -E "$bad_port_pattern" || true)"
if [[ -n "$bad" ]]; then
  die "unexpected public service ports: $bad"
fi

log "edge checks passed"
