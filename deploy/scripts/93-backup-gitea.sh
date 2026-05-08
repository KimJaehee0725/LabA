#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"
mkdir -p "$BACKUP_ROOT/files"

if [[ "$DRY_RUN" == "true" ]]; then
  echo "+ docker exec -u git gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip"
else
  docker exec -u git gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
  docker cp gitea:/tmp/gitea-dump.zip "$BACKUP_ROOT/files/gitea-dump.zip"
fi
