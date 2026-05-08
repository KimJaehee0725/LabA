#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"

mkdir -p "$BACKUP_ROOT/files" "$BACKUP_ROOT/mongo"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "+ docker exec overleaf-mongo mongodump --archive=/tmp/overleaf.archive --db sharelatex"
  echo "+ tar -C /srv/lab-platform/data/overleaf -czf $BACKUP_ROOT/files/overleaf-projects.tar.gz overleaf"
else
  docker exec overleaf-mongo mongodump --archive=/tmp/overleaf.archive --db sharelatex
  docker cp overleaf-mongo:/tmp/overleaf.archive "$BACKUP_ROOT/mongo/overleaf.archive"
  tar -C /srv/lab-platform/data/overleaf -czf "$BACKUP_ROOT/files/overleaf-projects.tar.gz" overleaf
fi
