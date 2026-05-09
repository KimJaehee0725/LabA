#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/60-nextcloud.env"
require_cmd docker

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"

apps=(
  richdocuments
  user_oidc
  calendar
  contacts
  notes
  tasks
  groupfolders
  collectives
  tables
  deck
  integration_github
)

for app in "${apps[@]}"; do
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:install "$app" || true
  docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ app:enable "$app"
done

docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ background:cron
