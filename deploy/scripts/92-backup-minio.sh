#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="${BACKUP_ROOT:-/srv/lab-platform/backups/archive/daily/$(date -u +%F)}"
DRY_RUN="${DRY_RUN:-false}"
buckets=(plane-uploads gitea-lfs mlflow-artifacts)

mkdir -p "$BACKUP_ROOT/minio"
for bucket in "${buckets[@]}"; do
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "+ mc mirror local/$bucket $BACKUP_ROOT/minio/$bucket"
  else
    docker exec lab-minio-mc mc mirror "local/$bucket" "$BACKUP_ROOT/minio/$bucket"
  fi
done
