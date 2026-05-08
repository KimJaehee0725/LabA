#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/30-gitea.env"

GITEA_CONTAINER="${GITEA_CONTAINER:-gitea}"
ORG_FILE="${ORG_FILE:-/tmp/lab-gitea-orgs.txt}"

if [[ -n "${GITEA_BOOTSTRAP_ADMIN_USER:-}" && -n "${GITEA_BOOTSTRAP_ADMIN_PASSWORD:-}" && -n "${GITEA_BOOTSTRAP_ADMIN_EMAIL:-}" ]]; then
  if docker exec --user git "$GITEA_CONTAINER" \
    gitea admin user list --config /data/gitea/conf/app.ini |
    awk '{print $2}' | grep -Fxq "$GITEA_BOOTSTRAP_ADMIN_USER"; then
    echo "Gitea bootstrap admin already exists: $GITEA_BOOTSTRAP_ADMIN_USER"
  else
    docker exec --user git "$GITEA_CONTAINER" \
      gitea admin user create \
      --config /data/gitea/conf/app.ini \
      --username "$GITEA_BOOTSTRAP_ADMIN_USER" \
      --password "$GITEA_BOOTSTRAP_ADMIN_PASSWORD" \
      --email "$GITEA_BOOTSTRAP_ADMIN_EMAIL" \
      --admin \
      --must-change-password=false >/dev/null
    echo "Gitea bootstrap admin created: $GITEA_BOOTSTRAP_ADMIN_USER"
  fi
else
  echo "Skipping Gitea bootstrap admin because GITEA_BOOTSTRAP_ADMIN_* is not fully configured."
fi

cat >"$ORG_FILE" <<'ORG'
lab-code
lab-models
lab-datasets
lab-papers
ORG

echo "Create these private organizations after first admin/OIDC login:"
cat "$ORG_FILE"
echo "Use the Gitea UI or admin CLI with a server-side token; do not store tokens in this repository."
docker exec "$GITEA_CONTAINER" gitea --version
