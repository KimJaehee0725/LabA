#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env"

AUTH_URL="${AUTH_URL:-https://auth.lab.snu.ac.kr}"
COMPOSE_FILE="${LAB_PLATFORM_ROOT}/compose/authentik/docker-compose.yml"
GROUP_CHECK_RETRIES="${AUTHENTIK_GROUP_CHECK_RETRIES:-40}"
GROUP_CHECK_SLEEP="${AUTHENTIK_GROUP_CHECK_SLEEP:-3}"
curl_args=(-ksSfL)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_args+=(--resolve "$CURL_RESOLVE")
fi
curl_probe_args=(-ksS)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_probe_args+=(--resolve "$CURL_RESOLVE")
fi

docker compose \
  --env-file "$ENV_DIR/00-global.env" \
  --env-file "$ENV_DIR/10-core.env" \
  --env-file "$ENV_DIR/20-authentik.env" \
  -f "$COMPOSE_FILE" \
  -p lab_authentik ps

status_code="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$AUTH_URL/api/v3/root/config/" || true)"
if [[ ! "$status_code" =~ ^[234][0-9][0-9]$ ]]; then
  die "authentik root config endpoint returned HTTP $status_code"
fi

if [[ "${AUTHENTIK_CHECK_DISCOVERY_SLUGS:-}" != "" ]]; then
  IFS=',' read -r -a discovery_slugs <<<"$AUTHENTIK_CHECK_DISCOVERY_SLUGS"
  for slug in "${discovery_slugs[@]}"; do
    slug="${slug//[[:space:]]/}"
    [[ -n "$slug" ]] || continue
    curl "${curl_args[@]}" "$AUTH_URL/application/o/$slug/.well-known/openid-configuration" >/dev/null
  done
fi

check_groups() {
  docker exec authentik-worker ak shell -c '
from authentik.core.models import Group

required = {"lab-admin", "lab-member", "lab-collab", "lab-guest"}
existing = set(Group.objects.filter(name__in=required).values_list("name", flat=True))
missing = sorted(required - existing)
if missing:
    raise SystemExit("missing authentik groups: " + ", ".join(missing))
' >/dev/null 2>&1
}

for attempt in $(seq 1 "$GROUP_CHECK_RETRIES"); do
  if check_groups; then
    echo "authentik reachability and group checks passed"
    exit 0
  fi
  if [[ "$attempt" -lt "$GROUP_CHECK_RETRIES" ]]; then
    sleep "$GROUP_CHECK_SLEEP"
  fi
done

die "required authentik groups were not visible after waiting"
