#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env"
require_cmd openssl

ROOT_DOMAIN="${ROOT_DOMAIN:-lab.example.ac.kr}"
AUTH_DOMAIN="${AUTH_DOMAIN:-auth.${ROOT_DOMAIN}}"
CERT_FILE="${CERT_FILE:-${LAB_STACK_ROOT}/certs/staging.crt}"
KEY_FILE="${KEY_FILE:-${LAB_STACK_ROOT}/certs/private/staging.key}"
CERT_DIR="$(dirname "$CERT_FILE")"
KEY_DIR="$(dirname "$KEY_FILE")"
FORCE="${FORCE:-false}"

domains=(
  "$AUTH_DOMAIN"
  "${PORTAL_DOMAIN:-${ROOT_DOMAIN}}"
  "${HULY_DOMAIN:-huly.${ROOT_DOMAIN}}"
  "${FILES_DOMAIN:-files.${ROOT_DOMAIN}}"
  "${S3_DOMAIN:-s3.${ROOT_DOMAIN}}"
  "${HF_DOMAIN:-hf.${ROOT_DOMAIN}}"
  "${OVERLEAF_DOMAIN:-overleaf.${ROOT_DOMAIN}}"
)

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" && "$FORCE" != "true" ]]; then
  run_cmd chmod 0600 "$KEY_FILE"
  log "existing self-signed certificate found; set FORCE=true to replace it"
  exit 0
fi

run_cmd install -d -m 0750 "$CERT_DIR"
run_cmd install -d -m 0700 "$KEY_DIR"

san_entries=""
for idx in "${!domains[@]}"; do
  san_entries+="DNS.$((idx + 1)) = ${domains[$idx]}"$'\n'
done

openssl_conf="$(mktemp)"
trap 'rm -f "$openssl_conf"' EXIT
{
  printf '[req]\n'
  printf 'default_bits = 4096\n'
  printf 'prompt = no\n'
  printf 'default_md = sha256\n'
  printf 'distinguished_name = dn\n'
  printf 'x509_extensions = v3_req\n\n'
  printf '[dn]\n'
  printf 'CN = %s\n\n' "$AUTH_DOMAIN"
  printf '[v3_req]\n'
  printf 'basicConstraints = CA:FALSE\n'
  printf 'keyUsage = digitalSignature, keyEncipherment\n'
  printf 'extendedKeyUsage = serverAuth\n'
  printf 'subjectAltName = @alt_names\n\n'
  printf '[alt_names]\n'
  printf '%s' "$san_entries"
} >"$openssl_conf"

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  echo "+ openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout $KEY_FILE -out $CERT_FILE -config <generated>"
  log "self-signed certificate dry-run completed for $CERT_FILE"
else
  openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -config "$openssl_conf"
  chmod 0644 "$CERT_FILE"
  chmod 0600 "$KEY_FILE"
  log "self-signed certificate ready at $CERT_FILE"
fi
