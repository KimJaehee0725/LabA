#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env"

PHASE2_REQUIRE_SMTP="${PHASE2_REQUIRE_SMTP:-true}"
PHASE2_REQUIRE_OIDC_ENV="${PHASE2_REQUIRE_OIDC_ENV:-true}"
PHASE2_REQUIRE_REAL_DOMAINS="${PHASE2_REQUIRE_REAL_DOMAINS:-true}"
AUTHENTIK_DATA_UID="${AUTHENTIK_DATA_UID:-1000}"
AUTHENTIK_DATA_GID="${AUTHENTIK_DATA_GID:-1000}"
AUTHENTIK_PHASE2_OIDC_APPS="${AUTHENTIK_PHASE2_OIDC_APPS:-huly,minio,hf-ui}"

status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

check_readable_file() {
  local path="$1"
  if [[ -r "$path" && -f "$path" ]]; then
    ok "readable file: $path"
  else
    fail "missing or unreadable file: $path"
  fi
}

check_dir() {
  local path="$1"
  if [[ -d "$path" ]]; then
    ok "directory exists: $path"
  else
    fail "missing directory: $path"
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

check_non_placeholder() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set"
  fi
}

check_real_value() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  elif [[ "$PHASE2_REQUIRE_REAL_DOMAINS" == "true" || "$PHASE2_REQUIRE_REAL_DOMAINS" == "1" ]] && is_example_value "$value"; then
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

check_uri_var() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
    return
  fi
  IFS=',' read -r -a uris <<<"$value"
  local uri
  for uri in "${uris[@]}"; do
    uri="${uri//[[:space:]]/}"
    [[ -n "$uri" ]] || continue
    if [[ "$uri" == https://* ]]; then
      if [[ "$PHASE2_REQUIRE_REAL_DOMAINS" == "true" || "$PHASE2_REQUIRE_REAL_DOMAINS" == "1" ]] && is_example_value "$uri"; then
        fail "$name contains an example redirect URI: ${uri}"
      else
        ok "$name contains HTTPS redirect URI: ${uri}"
      fi
    else
      fail "$name contains non-HTTPS redirect URI: ${uri}"
    fi
  done
}

check_oidc_app_env() {
  local app="$1"
  local prefix
  case "$app" in
    huly) prefix="HULY" ;;
    minio) prefix="MINIO" ;;
    hf-ui) prefix="HF_UI" ;;
    *) fail "unsupported Phase 2 OIDC app slug: $app"; return ;;
  esac
  check_non_placeholder "${prefix}_OIDC_CLIENT_ID"
  check_secret_var "${prefix}_OIDC_CLIENT_SECRET"
  check_uri_var "${prefix}_OIDC_REDIRECT_URIS"
}

require_cmd docker
require_cmd stat

check_dir "$LAB_STACK_ROOT"
check_dir "$ENV_DIR"
check_readable_file "$ENV_DIR/00-global.env"
check_readable_file "$ENV_DIR/10-core.env"
check_readable_file "$ENV_DIR/20-authentik.env"
check_readable_file "$LAB_STACK_ROOT/nginx/nginx.conf"
check_readable_file "$LAB_STACK_ROOT/certs/staging.crt"
check_readable_file "$LAB_STACK_ROOT/certs/private/staging.key"

key_mode="$(stat -c '%a' "$LAB_STACK_ROOT/certs/private/staging.key" 2>/dev/null || true)"
if [[ "$key_mode" =~ ^[0-7]+$ && $((10#$key_mode)) -le 600 ]]; then
  ok "TLS private key mode is $key_mode"
else
  fail "TLS private key mode must be 0600 or stricter; observed ${key_mode:-missing}"
fi

authentik_owner="$(stat -c '%u:%g' "$LAB_STACK_ROOT/data/authentik/media" 2>/dev/null || true)"
if [[ "$authentik_owner" == "${AUTHENTIK_DATA_UID}:${AUTHENTIK_DATA_GID}" ]]; then
  ok "Authentik media ownership is $authentik_owner"
else
  fail "Authentik media ownership must be ${AUTHENTIK_DATA_UID}:${AUTHENTIK_DATA_GID}; observed ${authentik_owner:-missing}"
fi

check_network "$LABSTACK_PUBLIC_NETWORK"
check_network "$LABSTACK_BACKEND_NETWORK"
check_network "$LABSTACK_DATA_NETWORK"

check_secret_var AUTHENTIK_SECRET_KEY
check_secret_var AUTHENTIK_BOOTSTRAP_PASSWORD
check_secret_var AUTHENTIK_BOOTSTRAP_TOKEN
check_secret_var AUTHENTIK_POSTGRES_PASSWORD
check_real_value ROOT_DOMAIN
check_real_value AUTH_DOMAIN
check_real_value HULY_DOMAIN
check_real_value FILES_DOMAIN
check_real_value HF_DOMAIN

if [[ "$PHASE2_REQUIRE_SMTP" == "true" || "$PHASE2_REQUIRE_SMTP" == "1" ]]; then
  check_real_value AUTHENTIK_EMAIL__HOST
  check_non_placeholder AUTHENTIK_EMAIL__PORT
  check_non_placeholder AUTHENTIK_EMAIL__USERNAME
  check_secret_var AUTHENTIK_EMAIL__PASSWORD
  check_real_value AUTHENTIK_EMAIL__FROM
else
  log "skipping strict SMTP env checks because PHASE2_REQUIRE_SMTP=$PHASE2_REQUIRE_SMTP"
fi

if [[ "$PHASE2_REQUIRE_OIDC_ENV" == "true" || "$PHASE2_REQUIRE_OIDC_ENV" == "1" ]]; then
  IFS=',' read -r -a oidc_apps <<<"$AUTHENTIK_PHASE2_OIDC_APPS"
  for app in "${oidc_apps[@]}"; do
    app="${app//[[:space:]]/}"
    [[ -n "$app" ]] || continue
    check_oidc_app_env "$app"
  done
else
  log "skipping strict OIDC env checks because PHASE2_REQUIRE_OIDC_ENV=$PHASE2_REQUIRE_OIDC_ENV"
fi

if [[ "$status" -eq 0 ]]; then
  log "phase2 preflight checks passed"
else
  log "phase2 preflight checks failed"
fi

exit "$status"
