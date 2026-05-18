#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

PHASE6_REQUIRE_REAL_DOMAINS_INCOMING="${PHASE6_REQUIRE_REAL_DOMAINS:-}"
PHASE6_REQUIRE_SMTP="${PHASE6_REQUIRE_SMTP:-false}"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/70-overleaf.env"

OVERLEAF_DOMAIN="${OVERLEAF_DOMAIN:-overleaf.lab.example.ac.kr}"
OVERLEAF_SITE_URL="${OVERLEAF_SITE_URL:-https://${OVERLEAF_DOMAIN}}"
OVERLEAF_SITE_URL="${OVERLEAF_SITE_URL%/}"
OVERLEAF_CONTAINER="${OVERLEAF_CONTAINER:-overleaf}"
OVERLEAF_MONGO_CONTAINER="${OVERLEAF_MONGO_CONTAINER:-overleaf-mongo}"
OVERLEAF_REDIS_CONTAINER="${OVERLEAF_REDIS_CONTAINER:-overleaf-redis}"
PHASE6_REQUIRE_REAL_DOMAINS="${PHASE6_REQUIRE_REAL_DOMAINS:-true}"
if [[ -n "$PHASE6_REQUIRE_REAL_DOMAINS_INCOMING" ]]; then
  PHASE6_REQUIRE_REAL_DOMAINS="$PHASE6_REQUIRE_REAL_DOMAINS_INCOMING"
fi

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

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" ||
    "$value" == change-me* ||
    "$value" == CHANGE-ME* ||
    "$value" == todo* ||
    "$value" == TODO* ]]
}

is_example_value() {
  local value="${1:-}"
  [[ "$value" == *example.edu* || "$value" == *example.ac.kr* ]]
}

check_real_value() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  elif is_true "$PHASE6_REQUIRE_REAL_DOMAINS" && is_example_value "$value"; then
    fail "$name still uses an example domain/value"
  else
    ok "$name is set"
  fi
}

check_secret_var() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set without printing its value"
  fi
}

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

require_cmd curl
require_cmd docker

curl_resolve_args=()
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  IFS=',' read -r -a curl_resolve_values <<<"$CURL_RESOLVE"
  for curl_resolve in "${curl_resolve_values[@]}"; do
    curl_resolve="${curl_resolve//[[:space:]]/}"
    [[ -n "$curl_resolve" ]] || continue
    curl_resolve_args+=(--resolve "$curl_resolve")
  done
elif [[ "${STAGING_IP:-}" != "" ]]; then
  curl_resolve_args+=(--resolve "${OVERLEAF_DOMAIN}:443:${STAGING_IP}")
fi
curl_probe_args=(-ksS --noproxy "*" "${curl_resolve_args[@]}")

check_real_value OVERLEAF_DOMAIN
check_real_value OVERLEAF_SITE_URL
check_secret_var OVERLEAF_SESSION_SECRET
check_secret_var OVERLEAF_REDIS_PASSWORD

if is_true "$PHASE6_REQUIRE_SMTP"; then
  check_real_value OVERLEAF_SMTP_HOST
  check_real_value OVERLEAF_SMTP_FROM
  check_secret_var OVERLEAF_SMTP_PASSWORD
  if is_placeholder "${OVERLEAF_SMTP_USER:-}"; then
    fail "OVERLEAF_SMTP_USER is unset or still a placeholder"
  else
    ok "OVERLEAF_SMTP_USER is set"
  fi
else
  log "skipping strict Overleaf SMTP env checks because PHASE6_REQUIRE_SMTP=$PHASE6_REQUIRE_SMTP"
fi

check_container "$OVERLEAF_CONTAINER"
check_container "$OVERLEAF_MONGO_CONTAINER"
check_container "$OVERLEAF_REDIS_CONTAINER"
check_no_host_ports "$OVERLEAF_CONTAINER"
check_no_host_ports "$OVERLEAF_MONGO_CONTAINER"
check_no_host_ports "$OVERLEAF_REDIS_CONTAINER"

if docker inspect nginx >/dev/null 2>&1 && docker exec nginx nginx -t >/dev/null; then
  ok "nginx config test passed"
else
  fail "nginx config test failed or nginx container is missing"
fi

if docker exec "$OVERLEAF_CONTAINER" node --version >/dev/null; then
  ok "Overleaf node runtime is available"
else
  fail "Overleaf node runtime is not available"
fi

if docker exec "$OVERLEAF_CONTAINER" bash -lc 'command -v latexmk >/dev/null'; then
  ok "latexmk is available in Overleaf image"
else
  fail "latexmk is missing from Overleaf image"
fi

if docker exec "$OVERLEAF_CONTAINER" bash -lc 'command -v kpsewhich >/dev/null && kpsewhich kotex.sty >/dev/null'; then
  ok "Korean LaTeX package kotex is available"
else
  fail "Korean LaTeX package kotex is missing"
fi

if docker exec "$OVERLEAF_CONTAINER" bash -lc 'command -v kpsewhich >/dev/null && kpsewhich fontspec.sty >/dev/null && kpsewhich xetexko.sty >/dev/null && kpsewhich luatexko.sty >/dev/null'; then
  ok "XeLaTeX/LuaLaTeX Korean dependencies are available"
else
  fail "XeLaTeX/LuaLaTeX Korean dependencies are missing"
fi

if docker exec "$OVERLEAF_REDIS_CONTAINER" redis-cli -a "${OVERLEAF_REDIS_PASSWORD:-}" --no-auth-warning ping | grep -q PONG; then
  ok "Overleaf Redis auth ping succeeded"
else
  fail "Overleaf Redis auth ping failed"
fi

if docker exec "$OVERLEAF_MONGO_CONTAINER" mongosh --quiet --eval 'db.adminCommand({ ping: 1 }).ok' | grep -q 1; then
  ok "Overleaf Mongo ping succeeded"
else
  fail "Overleaf Mongo ping failed"
fi

if docker exec "$OVERLEAF_MONGO_CONTAINER" mongosh --quiet --eval 'rs.status().ok' | grep -q 1; then
  ok "Overleaf Mongo replica set is initialized"
else
  fail "Overleaf Mongo replica set is not initialized; run 81-bootstrap-overleaf.sh"
fi

if docker exec "$OVERLEAF_CONTAINER" node -e '
const http = require("http");
const req = http.get({ host: "127.0.0.1", port: 80, path: "/", timeout: 5000 }, (res) => {
  res.resume();
  res.on("end", () => process.exit(res.statusCode >= 200 && res.statusCode < 500 ? 0 : 1));
});
req.on("timeout", () => req.destroy(new Error("timeout")));
req.on("error", () => process.exit(1));
' >/dev/null; then
  ok "Overleaf container HTTP endpoint responded"
else
  fail "Overleaf container HTTP endpoint did not respond"
fi

index_status="$(curl "${curl_probe_args[@]}" -o /dev/null -w '%{http_code}' "$OVERLEAF_SITE_URL/" || true)"
if [[ "$index_status" =~ ^[23][0-9][0-9]$ ]]; then
  ok "Overleaf public route returned HTTP $index_status"
else
  fail "Overleaf public route returned HTTP ${index_status:-000}"
fi

if [[ "$status" -eq 0 ]]; then
  log "overleaf checks passed"
else
  log "overleaf checks failed"
fi

exit "$status"
