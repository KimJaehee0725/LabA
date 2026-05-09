#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"
GRIST_DATA_DIR="${GRIST_DATA_DIR:-/srv/lab-platform/data/grist}"
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

mkdir -p "$BACKUP_ROOT/files"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "+ tar -C $GRIST_DATA_DIR -czf $BACKUP_ROOT/files/grist-persist.tar.gz persist"
else
  test -d "$GRIST_DATA_DIR/persist"
  tar -C "$GRIST_DATA_DIR" -czf "$BACKUP_ROOT/files/grist-persist.tar.gz" persist
  test -s "$BACKUP_ROOT/files/grist-persist.tar.gz"
fi
