#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_env_file "$ENV_DIR/00-global.env"

LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
LAB_MINIO_DATA_ROOT="${LAB_MINIO_DATA_ROOT:-/mnt/hdd/minio}"

df -h "$LAB_STACK_ROOT" "$LAB_BACKUP_ROOT" "$LAB_MINIO_DATA_ROOT" 2>/dev/null || true
du -h -d 2 "$LAB_STACK_ROOT/data" "$LAB_BACKUP_ROOT" "$LAB_MINIO_DATA_ROOT" 2>/dev/null | sort -h
