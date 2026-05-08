#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"

mkdir -p "$BACKUP_ROOT/files"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "+ occ maintenance:mode --on"
  echo "+ tar -C /srv/lab-platform/data/nextcloud -czf $BACKUP_ROOT/files/nextcloud-data-config-apps.tar.gz data config custom_apps"
  echo "+ occ maintenance:mode --off"
else
  docker exec -u www-data nextcloud php occ maintenance:mode --on
  tar -C /srv/lab-platform/data/nextcloud -czf "$BACKUP_ROOT/files/nextcloud-data-config-apps.tar.gz" data config custom_apps
  docker exec -u www-data nextcloud php occ maintenance:mode --off
fi
