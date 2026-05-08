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

docker exec -i postgres psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-postgres}" <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${AUTHENTIK_POSTGRES_USER:-authentik_user}') THEN CREATE ROLE ${AUTHENTIK_POSTGRES_USER:-authentik_user} LOGIN PASSWORD '${AUTHENTIK_POSTGRES_PASSWORD:-change-me}'; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${GITEA_DB_USER:-gitea_user}') THEN CREATE ROLE ${GITEA_DB_USER:-gitea_user} LOGIN PASSWORD '${GITEA_DB_PASSWORD:-change-me}'; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${PLANE_DB_USER:-plane_user}') THEN CREATE ROLE ${PLANE_DB_USER:-plane_user} LOGIN PASSWORD '${PLANE_DB_PASSWORD:-change-me}'; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${MLFLOW_DB_USER:-mlflow_user}') THEN CREATE ROLE ${MLFLOW_DB_USER:-mlflow_user} LOGIN PASSWORD '${MLFLOW_DB_PASSWORD:-change-me}'; END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${NEXTCLOUD_DB_USER:-nextcloud_user}') THEN CREATE ROLE ${NEXTCLOUD_DB_USER:-nextcloud_user} LOGIN PASSWORD '${NEXTCLOUD_DB_PASSWORD:-change-me}'; END IF;
END
\$\$;
SELECT 'CREATE DATABASE ${AUTHENTIK_POSTGRES_DB:-authentik} OWNER ${AUTHENTIK_POSTGRES_USER:-authentik_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${AUTHENTIK_POSTGRES_DB:-authentik}')\gexec
SELECT 'CREATE DATABASE ${GITEA_DB_NAME:-gitea} OWNER ${GITEA_DB_USER:-gitea_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${GITEA_DB_NAME:-gitea}')\gexec
SELECT 'CREATE DATABASE ${PLANE_DB_NAME:-plane} OWNER ${PLANE_DB_USER:-plane_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${PLANE_DB_NAME:-plane}')\gexec
SELECT 'CREATE DATABASE ${MLFLOW_DB_NAME:-mlflow} OWNER ${MLFLOW_DB_USER:-mlflow_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${MLFLOW_DB_NAME:-mlflow}')\gexec
SELECT 'CREATE DATABASE ${NEXTCLOUD_DB_NAME:-nextcloud} OWNER ${NEXTCLOUD_DB_USER:-nextcloud_user}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${NEXTCLOUD_DB_NAME:-nextcloud}')\gexec
SQL
