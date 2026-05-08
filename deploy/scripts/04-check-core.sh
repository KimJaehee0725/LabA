#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env"
require_cmd docker

docker exec postgres pg_isready -U "${POSTGRES_USER:-postgres}"
docker exec redis redis-cli -a "${REDIS_PASSWORD:?REDIS_PASSWORD required}" ping | grep -q PONG
docker exec minio curl -fsS http://localhost:9000/minio/health/live >/dev/null
log "core checks passed"
