#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/30-gitea.env" \
  "$ENV_DIR/40-plane.env" \
  "$ENV_DIR/50-mlflow.env" \
  "$ENV_DIR/60-nextcloud.env"

require_cmd docker

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  log "would create/update service roles and databases in postgres container"
  exit 0
fi

bootstrap_database() {
  local label="$1"
  local db_name="$2"
  local db_user="$3"
  local db_password="$4"

  if [[ -z "$db_password" || "$db_password" == change-me* ]]; then
    log "skipping $label database bootstrap because its password is not configured"
    return 0
  fi

  docker exec -i postgres psql \
    -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER:-postgres}" \
    -v db_name="$db_name" \
    -v db_user="$db_user" \
    -v db_password="$db_password" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'db_user', :'db_password')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'db_user')\gexec
SQL
}

bootstrap_database "authentik" "${AUTHENTIK_POSTGRES_DB:-authentik}" "${AUTHENTIK_POSTGRES_USER:-authentik_user}" "${AUTHENTIK_POSTGRES_PASSWORD:-}"
bootstrap_database "gitea" "${GITEA_DB_NAME:-gitea}" "${GITEA_DB_USER:-gitea_user}" "${GITEA_DB_PASSWORD:-}"
bootstrap_database "plane" "${PLANE_DB_NAME:-plane}" "${PLANE_DB_USER:-plane_user}" "${PLANE_DB_PASSWORD:-}"
bootstrap_database "mlflow" "${MLFLOW_DB_NAME:-mlflow}" "${MLFLOW_DB_USER:-mlflow_user}" "${MLFLOW_DB_PASSWORD:-}"
bootstrap_database "nextcloud" "${NEXTCLOUD_DB_NAME:-nextcloud}" "${NEXTCLOUD_DB_USER:-nextcloud_user}" "${NEXTCLOUD_DB_PASSWORD:-}"
