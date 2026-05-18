#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env" "$ENV_DIR/30-huly.env"

PHASE3_REQUIRE_REAL_DOMAINS="${PHASE3_REQUIRE_REAL_DOMAINS:-true}"
PHASE3_REQUIRE_GITHUB="${PHASE3_REQUIRE_GITHUB:-${HULY_ENABLE_GITHUB:-true}}"
PHASE3_REQUIRE_CALENDAR="${PHASE3_REQUIRE_CALENDAR:-${HULY_ENABLE_CALENDAR:-true}}"
PHASE3_REQUIRE_OIDC="${PHASE3_REQUIRE_OIDC:-true}"
HULY_COMPOSE_FILE="${HULY_COMPOSE_FILE:-${LAB_STACK_ROOT}/compose/huly/docker-compose.yml}"
HULY_NGINX_FILE="${HULY_NGINX_FILE:-${LAB_STACK_ROOT}/nginx/conf.d/20-huly.conf}"

status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
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

is_true() {
  [[ "${1:-}" == "true" || "${1:-}" == "1" || "${1:-}" == "yes" ]]
}

check_readable_file() {
  local path="$1"
  if [[ -r "$path" && -f "$path" ]]; then
    ok "readable file: $path"
  else
    fail "missing or unreadable file: $path"
  fi
}

check_network() {
  local name="$1"
  if docker network inspect "$name" >/dev/null 2>&1; then
    ok "docker network exists: $name"
  else
    fail "missing docker network: $name"
  fi
}

check_non_placeholder() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
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

check_url_safe_var() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  elif [[ "$value" =~ [[:space:]@:/\?\#\&%] ]]; then
    fail "$name must be URL-safe because it is interpolated into Huly URLs"
  else
    ok "$name is URL-safe"
  fi
}

check_real_value() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  elif is_true "$PHASE3_REQUIRE_REAL_DOMAINS" && is_example_value "$value"; then
    fail "$name still uses an example domain/value"
  else
    ok "$name is set"
  fi
}

load_secret_file_fallback() {
  local value_var="$1"
  local file_var="$2"
  local value="${!value_var:-}"
  local file="${!file_var:-}"

  if is_placeholder "$value" && [[ -n "$file" && -r "$file" ]]; then
    printf -v "$value_var" '%s' "$(<"$file")"
    export "$value_var"
    ok "$value_var loaded from $file_var"
  fi
}

require_cmd docker

load_secret_file_fallback HULY_GITHUB_PRIVATE_KEY HULY_GITHUB_PRIVATE_KEY_FILE
load_secret_file_fallback HULY_GOOGLE_CALENDAR_CREDENTIALS HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE

check_readable_file "$ENV_DIR/00-global.env"
check_readable_file "$ENV_DIR/10-core.env"
check_readable_file "$ENV_DIR/20-authentik.env"
check_readable_file "$ENV_DIR/30-huly.env"
check_readable_file "$HULY_COMPOSE_FILE"
check_readable_file "$HULY_NGINX_FILE"

check_network "$LABSTACK_BACKEND_NETWORK"
check_network "$LABSTACK_DATA_NETWORK"

check_real_value AUTH_DOMAIN
check_real_value HULY_DOMAIN
check_non_placeholder HULY_VERSION
check_non_placeholder HULY_DESKTOP_CHANNEL
check_url_safe_var HULY_COCKROACH_PASSWORD
check_url_safe_var HULY_MINIO_ROOT_USER
check_url_safe_var HULY_MINIO_ROOT_PASSWORD
check_secret_var HULY_REDPANDA_ADMIN_PASSWORD
check_secret_var HULY_SERVER_SECRET

if is_true "$PHASE3_REQUIRE_OIDC"; then
  check_non_placeholder HULY_OIDC_CLIENT_ID
  check_secret_var HULY_OIDC_CLIENT_SECRET
  expected_redirect="https://${HULY_DOMAIN}/_accounts/auth/openid/callback"
  redirect_found=false
  IFS=',' read -r -a redirect_uris <<<"${HULY_OIDC_REDIRECT_URIS:-}"
  for redirect_uri in "${redirect_uris[@]}"; do
    redirect_uri="${redirect_uri//[[:space:]]/}"
    if [[ "$redirect_uri" == "$expected_redirect" ]]; then
      redirect_found=true
      break
    fi
  done
  if [[ "$redirect_found" == "true" ]]; then
    ok "HULY_OIDC_REDIRECT_URIS contains $expected_redirect"
  else
    fail "HULY_OIDC_REDIRECT_URIS must contain $expected_redirect"
  fi
fi

if is_true "$PHASE3_REQUIRE_GITHUB"; then
  check_non_placeholder HULY_GITHUB_APP_ID
  check_non_placeholder HULY_GITHUB_APP_SLUG
  check_non_placeholder HULY_GITHUB_CLIENT_ID
  check_secret_var HULY_GITHUB_CLIENT_SECRET
  check_secret_var HULY_GITHUB_WEBHOOK_SECRET
  check_secret_var HULY_GITHUB_PRIVATE_KEY
else
  log "skipping strict GitHub App checks because PHASE3_REQUIRE_GITHUB=$PHASE3_REQUIRE_GITHUB"
fi

if is_true "$PHASE3_REQUIRE_CALENDAR"; then
  check_secret_var HULY_GOOGLE_CALENDAR_CREDENTIALS
else
  log "skipping strict Google Calendar checks because PHASE3_REQUIRE_CALENDAR=$PHASE3_REQUIRE_CALENDAR"
fi

if docker compose -f "$HULY_COMPOSE_FILE" config >/dev/null; then
  ok "Huly compose renders"
else
  fail "Huly compose failed to render"
fi

if grep -q '/_accounts' "$HULY_NGINX_FILE" &&
  grep -q '/_transactor' "$HULY_NGINX_FILE" &&
  grep -q '/_github' "$HULY_NGINX_FILE" &&
  grep -q '/_calendar' "$HULY_NGINX_FILE"; then
  ok "Huly Nginx route includes core, GitHub, and Calendar paths"
else
  fail "Huly Nginx route is missing one or more required paths"
fi

if [[ "$status" -eq 0 ]]; then
  log "phase3 Huly preflight checks passed"
else
  log "phase3 Huly preflight checks failed"
fi

exit "$status"
