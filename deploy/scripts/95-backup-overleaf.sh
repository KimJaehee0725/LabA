#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_common_args "$@"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/70-overleaf.env" \
  "$ENV_DIR/90-backup.env"

OVERLEAF_MONGO_CONTAINER="${OVERLEAF_MONGO_CONTAINER:-overleaf-mongo}"
OVERLEAF_MONGO_DB="${OVERLEAF_MONGO_DB:-sharelatex}"
LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
BACKUP_ARCHIVE_ROOT="${BACKUP_ROOT:-${LAB_BACKUP_ROOT}/archive}"
OVERLEAF_BACKUP_ROOT="${OVERLEAF_BACKUP_ROOT:-${BACKUP_ARCHIVE_ROOT}/overleaf/$(date -u +%F)}"
OVERLEAF_DATA_ROOT="${OVERLEAF_DATA_ROOT:-${LAB_STACK_ROOT}/data/overleaf}"

run_cmd install -d -m 0750 "$OVERLEAF_BACKUP_ROOT/files" "$OVERLEAF_BACKUP_ROOT/mongo" "$OVERLEAF_BACKUP_ROOT/redis"

run_cmd docker exec "$OVERLEAF_MONGO_CONTAINER" mongodump \
  --archive=/tmp/overleaf.archive \
  --db "$OVERLEAF_MONGO_DB"
run_cmd docker cp "$OVERLEAF_MONGO_CONTAINER:/tmp/overleaf.archive" "$OVERLEAF_BACKUP_ROOT/mongo/overleaf.archive"
run_cmd docker exec "$OVERLEAF_MONGO_CONTAINER" rm -f /tmp/overleaf.archive

run_cmd tar -C "$OVERLEAF_DATA_ROOT" -czf "$OVERLEAF_BACKUP_ROOT/files/overleaf-files.tar.gz" overleaf
run_cmd tar -C "$OVERLEAF_DATA_ROOT" -czf "$OVERLEAF_BACKUP_ROOT/redis/overleaf-redis.tar.gz" redis

log "overleaf backup written to $OVERLEAF_BACKUP_ROOT"
