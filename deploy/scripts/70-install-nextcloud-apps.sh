#!/usr/bin/env bash
set -euo pipefail

apps=(richdocuments user_oidc calendar contacts notes tasks groupfolders)

for app in "${apps[@]}"; do
  docker exec -u www-data nextcloud php occ app:install "$app" || true
  docker exec -u www-data nextcloud php occ app:enable "$app"
done

docker exec -u www-data nextcloud php occ background:cron
