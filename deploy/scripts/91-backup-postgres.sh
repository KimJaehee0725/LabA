#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"
dbs=(authentik plane gitea mlflow nextcloud grist)

mkdir -p "$BACKUP_ROOT/postgres"
for db in "${dbs[@]}"; do
  out="$BACKUP_ROOT/postgres/$db.dump"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "+ docker exec postgres pg_dump -U postgres -Fc $db > $out"
  else
    docker exec postgres pg_dump -U postgres -Fc "$db" >"$out"
    test -s "$out"
  fi
done
