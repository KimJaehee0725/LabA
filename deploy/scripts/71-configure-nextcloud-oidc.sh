#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/60-nextcloud.env"
require_cmd docker

NEXTCLOUD_CONTAINER="${NEXTCLOUD_CONTAINER:-nextcloud}"
NEXTCLOUD_OIDC_PROVIDER_ID="${NEXTCLOUD_OIDC_PROVIDER_ID:-Authentik}"
NEXTCLOUD_DISCOVERY_URL="${NEXTCLOUD_DISCOVERY_URL:-https://${AUTH_DOMAIN:-auth.lab.snu.ac.kr}/application/o/nextcloud/.well-known/openid-configuration}"
NEXTCLOUD_OIDC_GROUP_WHITELIST_REGEX="${NEXTCLOUD_OIDC_GROUP_WHITELIST_REGEX:-^lab-(admin|member|collab|guest)$}"
NEXTCLOUD_OIDC_GROUP_PROVISIONING="${NEXTCLOUD_OIDC_GROUP_PROVISIONING:-1}"
NEXTCLOUD_OIDC_GROUP_RESTRICT_LOGIN="${NEXTCLOUD_OIDC_GROUP_RESTRICT_LOGIN:-1}"
COLLABORA_PUBLIC_URL="${COLLABORA_PUBLIC_URL:-${COLLABORA_URL:-https://${COLLABORA_DOMAIN:-office.lab.snu.ac.kr}}}"
COLLABORA_INTERNAL_URL="${COLLABORA_INTERNAL_URL:-http://collabora:9980}"

if [[ -z "${NEXTCLOUD_OIDC_CLIENT_SECRET:-}" || "${NEXTCLOUD_OIDC_CLIENT_SECRET:-}" == change-me* ]]; then
  die "set NEXTCLOUD_OIDC_CLIENT_SECRET in $ENV_DIR/60-nextcloud.env before running"
fi

provider_group_regex="$NEXTCLOUD_OIDC_GROUP_WHITELIST_REGEX"
if [[ "$provider_group_regex" != /* ]]; then
  provider_group_regex="/$provider_group_regex/"
fi

docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ user_oidc:provider "$NEXTCLOUD_OIDC_PROVIDER_ID" \
  --clientid="${NEXTCLOUD_OIDC_CLIENT_ID:-nextcloud}" \
  --clientsecret="$NEXTCLOUD_OIDC_CLIENT_SECRET" \
  --discoveryuri="$NEXTCLOUD_DISCOVERY_URL" \
  --scope="openid email profile groups" \
  --mapping-uid="sub" \
  --mapping-email="email" \
  --mapping-display-name="name" \
  --unique-uid=1 \
  --group-provisioning="$NEXTCLOUD_OIDC_GROUP_PROVISIONING" \
  --group-whitelist-regex="$provider_group_regex" \
  --group-restrict-login-to-whitelist="$NEXTCLOUD_OIDC_GROUP_RESTRICT_LOGIN"

docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set richdocuments wopi_url --value="$COLLABORA_INTERNAL_URL"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ config:app:set richdocuments public_wopi_url --value="$COLLABORA_PUBLIC_URL"
docker exec -u www-data "$NEXTCLOUD_CONTAINER" php occ richdocuments:activate-config \
  --wopi-url="$COLLABORA_INTERNAL_URL" \
  --callback-url="https://${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}"
