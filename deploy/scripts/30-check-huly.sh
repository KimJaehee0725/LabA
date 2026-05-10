#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env" "$ENV_DIR/30-huly.env"

HULY_COMPOSE_FILE="${HULY_COMPOSE_FILE:-${LAB_STACK_ROOT}/compose/huly/docker-compose.yml}"
HULY_URL="${HULY_URL:-https://${HULY_DOMAIN}}"
AUTH_URL="${AUTH_URL:-https://${AUTH_DOMAIN}}"
HULY_URL="${HULY_URL%/}"
AUTH_URL="${AUTH_URL%/}"
status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

is_true() {
  [[ "${1:-}" == "true" || "${1:-}" == "1" || "${1:-}" == "yes" ]]
}

curl_resolve_args=()
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  IFS=',' read -r -a curl_resolve_values <<<"$CURL_RESOLVE"
  for curl_resolve in "${curl_resolve_values[@]}"; do
    curl_resolve="${curl_resolve//[[:space:]]/}"
    [[ -n "$curl_resolve" ]] || continue
    curl_resolve_args+=(--resolve "$curl_resolve")
  done
elif [[ "${STAGING_IP:-}" != "" ]]; then
  curl_resolve_args+=(--resolve "${HULY_DOMAIN}:443:${STAGING_IP}")
  curl_resolve_args+=(--resolve "${AUTH_DOMAIN}:443:${STAGING_IP}")
fi
curl_probe_args=(-ksS "${curl_resolve_args[@]}")

require_cmd curl
require_cmd docker

check_container() {
  local name="$1"
  local state health
  if ! docker inspect "$name" >/dev/null 2>&1; then
    fail "missing container: $name"
    return
  fi
  state="$(docker inspect -f '{{.State.Status}}' "$name")"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name")"
  if [[ "$state" != "running" ]]; then
    fail "$name is not running: $state"
    return
  fi
  if [[ -n "$health" && "$health" != "healthy" ]]; then
    fail "$name health is $health"
    return
  fi
  ok "$name is running${health:+ and $health}"
}

check_no_host_ports() {
  local name="$1"
  local ports
  ports="$(docker inspect -f '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$name" 2>/dev/null || true)"
  if [[ -n "$ports" ]]; then
    fail "$name publishes host ports: $ports"
  else
    ok "$name publishes no host ports"
  fi
}

if docker compose -f "$HULY_COMPOSE_FILE" ps >/dev/null; then
  ok "Huly compose project is readable"
else
  fail "Huly compose project is not readable"
fi

core_containers=(
  huly-cockroach
  huly-redpanda
  huly-minio
  huly-elastic
  huly-rekoni
  huly-transactor
  huly-collaborator
  huly-account
  huly-workspace
  huly-front
  huly-fulltext
  huly-stats
  huly-kvs
)

for container in "${core_containers[@]}"; do
  check_container "$container"
  check_no_host_ports "$container"
done

if is_true "${HULY_ENABLE_GITHUB:-true}"; then
  check_container huly-github
  check_no_host_ports huly-github
else
  log "skipping huly-github runtime check because HULY_ENABLE_GITHUB=${HULY_ENABLE_GITHUB:-unset}"
fi

if is_true "${HULY_ENABLE_CALENDAR:-true}"; then
  check_container huly-mongodb
  check_no_host_ports huly-mongodb
  check_container huly-calendar
  check_no_host_ports huly-calendar
else
  log "skipping huly-calendar runtime check because HULY_ENABLE_CALENDAR=${HULY_ENABLE_CALENDAR:-unset}"
fi

if docker inspect nginx >/dev/null 2>&1; then
  if docker exec nginx nginx -t >/dev/null; then
    ok "nginx config test passed"
  else
    fail "nginx config test failed"
  fi
else
  fail "missing nginx container"
fi

huly_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$HULY_URL/" || true)"
if [[ "$huly_status" =~ ^[234][0-9][0-9]$ ]]; then
  ok "Huly front returned HTTP $huly_status"
else
  fail "Huly front returned HTTP ${huly_status:-000}"
fi

account_callback_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$HULY_URL/_accounts/auth/openid/callback" || true)"
if [[ "$account_callback_status" =~ ^[234][0-9][0-9]$ ]]; then
  ok "Huly OIDC callback route reached account service with HTTP $account_callback_status"
else
  fail "Huly OIDC callback route returned HTTP ${account_callback_status:-000}"
fi

discovery_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$AUTH_URL/application/o/huly/.well-known/openid-configuration" || true)"
if [[ "$discovery_status" =~ ^[234][0-9][0-9]$ ]]; then
  ok "Authentik Huly OIDC discovery returned HTTP $discovery_status"
else
  fail "Authentik Huly OIDC discovery returned HTTP ${discovery_status:-000}"
fi

if [[ "$status" -eq 0 ]]; then
  log "Huly runtime checks passed"
else
  log "Huly runtime checks failed"
fi

exit "$status"
