#!/usr/bin/env bash
set -euo pipefail

: "${NEXTCLOUD_OIDC_CLIENT_SECRET:?set NEXTCLOUD_OIDC_CLIENT_SECRET in the shell or server env before running}"

docker exec -u www-data nextcloud php occ user_oidc:provider "Authentik" \
  --clientid="${NEXTCLOUD_OIDC_CLIENT_ID:-nextcloud}" \
  --clientsecret="$NEXTCLOUD_OIDC_CLIENT_SECRET" \
  --discoveryuri="${NEXTCLOUD_DISCOVERY_URL:-https://auth.lab.snu.ac.kr/application/o/nextcloud/.well-known/openid-configuration}" \
  --scope="openid email profile groups" \
  --mapping-uid="sub" \
  --mapping-email="email" \
  --mapping-display-name="name" \
  --unique-uid=1

docker exec -u www-data nextcloud php occ richdocuments:activate-config
docker exec -u www-data nextcloud php occ config:app:set richdocuments wopi_url --value="${COLLABORA_URL:-https://office.lab.snu.ac.kr}"
