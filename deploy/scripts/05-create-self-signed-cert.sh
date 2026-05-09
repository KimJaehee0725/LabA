#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env"
require_cmd openssl

CERT_DIR="${LAB_PLATFORM_ROOT}/nginx/ssl"
CERT_FILE="${CERT_DIR}/origin.crt"
KEY_FILE="${CERT_DIR}/origin.key"
FORCE="${FORCE:-false}"

domains=(
  "${AUTH_DOMAIN:-auth.lab.snu.ac.kr}"
  "${GITEA_DOMAIN:-hub.lab.snu.ac.kr}"
  "${PLANE_DOMAIN:-lab.snu.ac.kr}"
  "${MLFLOW_DOMAIN:-mlflow.lab.snu.ac.kr}"
  "${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}"
  "${COLLABORA_DOMAIN:-office.lab.snu.ac.kr}"
  "${GRIST_DOMAIN:-data.lab.snu.ac.kr}"
  "${OVERLEAF_DOMAIN:-papers.lab.snu.ac.kr}"
  "${MINIO_CONSOLE_DOMAIN:-storage.lab.snu.ac.kr}"
)

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" && "$FORCE" != "true" ]]; then
  chmod 0600 "$KEY_FILE"
  log "existing self-signed certificate found; set FORCE=true to replace it"
  exit 0
fi

run_cmd install -d -m 0700 "$CERT_DIR"

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
  printf 'CN = %s\n\n' "${AUTH_DOMAIN:-auth.lab.snu.ac.kr}"
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
else
  openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -config "$openssl_conf"
  chmod 0644 "$CERT_FILE"
  chmod 0600 "$KEY_FILE"
fi

log "self-signed certificate ready at $CERT_FILE"
