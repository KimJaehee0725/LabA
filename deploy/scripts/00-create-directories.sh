#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
. "$COMMON_DIR/common.sh"

parse_common_args "$@"
load_env_file "$ENV_DIR/00-global.env"

LAB_MINIO_DATA_ROOT="${LAB_MINIO_DATA_ROOT:-/mnt/hdd/minio}"
LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"

install_dirs=(
  "$LAB_STACK_ROOT"
  "$LAB_STACK_ROOT/env"
  "$LAB_STACK_ROOT/compose"
  "$LAB_STACK_ROOT/certs"
  "$LAB_STACK_ROOT/nginx"
  "$LAB_STACK_ROOT/nginx/conf.d"
  "$LAB_STACK_ROOT/nginx/snippets"
  "$LAB_STACK_ROOT/authentik"
  "$LAB_STACK_ROOT/huly"
  "$LAB_STACK_ROOT/huly/seed"
  "$LAB_STACK_ROOT/huly/notion-sample"
  "$LAB_STACK_ROOT/minio"
  "$LAB_STACK_ROOT/minio/policies"
  "$LAB_STACK_ROOT/hf-ui"
  "$LAB_STACK_ROOT/hf-ui/app"
  "$LAB_STACK_ROOT/hf-ui/catalog"
  "$LAB_STACK_ROOT/overleaf"
  "$LAB_STACK_ROOT/portal"
  "$LAB_STACK_ROOT/data"
  "$LAB_STACK_ROOT/data/postgres"
  "$LAB_STACK_ROOT/data/redis"
  "$LAB_STACK_ROOT/data/authentik"
  "$LAB_STACK_ROOT/data/authentik/media"
  "$LAB_STACK_ROOT/data/authentik/certs"
  "$LAB_STACK_ROOT/data/authentik/custom-templates"
  "$LAB_STACK_ROOT/data/huly"
  "$LAB_STACK_ROOT/data/huly/cockroach"
  "$LAB_STACK_ROOT/data/huly/cockroach-certs"
  "$LAB_STACK_ROOT/data/huly/elastic"
  "$LAB_STACK_ROOT/data/huly/files"
  "$LAB_STACK_ROOT/data/huly/mongodb"
  "$LAB_STACK_ROOT/data/huly/redpanda"
  "$LAB_STACK_ROOT/data/overleaf"
  "$LAB_STACK_ROOT/data/overleaf/overleaf"
  "$LAB_STACK_ROOT/data/overleaf/mongo"
  "$LAB_STACK_ROOT/data/overleaf/redis"
  "$LAB_MINIO_DATA_ROOT"
  "$LAB_BACKUP_ROOT"
  "$LAB_BACKUP_ROOT/minio-smoke"
  "$LAB_BACKUP_ROOT/overleaf"
  "$LAB_STACK_ROOT/backups"
  "$LAB_STACK_ROOT/backups/archive"
  "$LAB_STACK_ROOT/backups/scripts"
  "$LAB_STACK_ROOT/logs"
  "$LAB_STACK_ROOT/logs/huly"
  "$LAB_STACK_ROOT/logs/nginx"
  "$LAB_STACK_ROOT/logs/overleaf"
  "$LAB_STACK_ROOT/reports"
)

for dir in "${install_dirs[@]}"; do
  run_cmd install -d -m 0750 "$dir"
done

run_cmd install -d -m 0700 "$LAB_STACK_ROOT/certs/private"
run_cmd install -d -m 0700 "$LAB_STACK_ROOT/secrets" "$LAB_STACK_ROOT/secrets/huly"

AUTHENTIK_DATA_UID="${AUTHENTIK_DATA_UID:-1000}"
AUTHENTIK_DATA_GID="${AUTHENTIK_DATA_GID:-1000}"
if is_dry_run || [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  run_cmd chown -R "${AUTHENTIK_DATA_UID}:${AUTHENTIK_DATA_GID}" "$LAB_STACK_ROOT/data/authentik"
else
  log "skipping Authentik data ownership fix because the script is not running as root"
fi

HULY_DATA_UID="${HULY_DATA_UID:-1000}"
HULY_DATA_GID="${HULY_DATA_GID:-1000}"
HULY_REDPANDA_UID="${HULY_REDPANDA_UID:-101}"
HULY_REDPANDA_GID="${HULY_REDPANDA_GID:-101}"
if is_dry_run || [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  run_cmd chown -R "${HULY_DATA_UID}:${HULY_DATA_GID}" \
    "$LAB_STACK_ROOT/data/huly/cockroach" \
    "$LAB_STACK_ROOT/data/huly/cockroach-certs" \
    "$LAB_STACK_ROOT/data/huly/elastic" \
    "$LAB_STACK_ROOT/data/huly/files" \
    "$LAB_STACK_ROOT/data/huly/mongodb"
  run_cmd chown -R "${HULY_REDPANDA_UID}:${HULY_REDPANDA_GID}" "$LAB_STACK_ROOT/data/huly/redpanda"
else
  log "skipping Huly data ownership fix because the script is not running as root"
fi

if compgen -G "$LAB_STACK_ROOT/env/*.env" >/dev/null; then
  env_files=("$LAB_STACK_ROOT"/env/*.env)
  run_cmd chmod 0640 "${env_files[@]}"
fi
