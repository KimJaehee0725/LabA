#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi
export DRY_RUN

"$SCRIPT_DIR/91-backup-postgres.sh"
"$SCRIPT_DIR/92-backup-minio.sh"
"$SCRIPT_DIR/93-backup-gitea.sh"
"$SCRIPT_DIR/94-backup-nextcloud.sh"
"$SCRIPT_DIR/95-backup-overleaf.sh"

echo "backup-all completed with DRY_RUN=$DRY_RUN"
