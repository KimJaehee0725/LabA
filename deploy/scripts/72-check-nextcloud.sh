#!/usr/bin/env bash
set -euo pipefail

NEXTCLOUD_URL="${NEXTCLOUD_URL:-https://files.lab.snu.ac.kr}"
COLLABORA_URL="${COLLABORA_URL:-https://office.lab.snu.ac.kr}"

curl -ksSf "$NEXTCLOUD_URL/status.php" >/dev/null
curl -ksSf "$COLLABORA_URL/hosting/discovery" >/dev/null
docker exec -u www-data nextcloud php occ status >/dev/null
echo "nextcloud and collabora checks passed"
