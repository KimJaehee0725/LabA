#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env"
require_cmd openssl

if [[ "${DRY_RUN:-false}" != "true" && "$EUID" -ne 0 ]]; then
  die "run this script as root so TLS private keys stay root-owned"
fi

CERT_DIR="${LAB_PLATFORM_ROOT}/nginx/ssl"
CA_CERT_FILE="${CERT_DIR}/lab-internal-ca.crt"
CA_KEY_FILE="${CERT_DIR}/lab-internal-ca.key"
CERT_FILE="${CERT_DIR}/origin.crt"
KEY_FILE="${CERT_DIR}/origin.key"
LAB_CA_BUNDLE_FILE="${LAB_CA_BUNDLE_FILE:-$LAB_PLATFORM_ROOT/gitea/ca-certificates.crt}"
SYSTEM_CA_BUNDLE_FILE="${SYSTEM_CA_BUNDLE_FILE:-/etc/ssl/certs/ca-certificates.crt}"
CA_VALID_DAYS="${CA_VALID_DAYS:-3650}"
LEAF_VALID_DAYS="${LEAF_VALID_DAYS:-397}"

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

if [[ "${DRY_RUN:-false}" == "true" ]]; then
  echo "+ install -d -o root -g root -m 0700 $CERT_DIR"
  echo "+ create or reuse internal CA at $CA_CERT_FILE"
  echo "+ backup existing $CERT_FILE and $KEY_FILE when present"
  echo "+ create CA-signed origin certificate chain at $CERT_FILE"
  echo "+ append $CA_CERT_FILE to $LAB_CA_BUNDLE_FILE"
  exit 0
fi

install -d -o root -g root -m 0700 "$CERT_DIR"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

backup_file() {
  local file="$1"
  local backup

  [[ -e "$file" ]] || return 0
  backup="${file}.bak.${timestamp}"
  if [[ -e "$backup" ]]; then
    backup="${file}.bak.${timestamp}.$$"
  fi
  cp -a "$file" "$backup"
  log "backed up $file to $backup"
}

san_entries=""
for idx in "${!domains[@]}"; do
  san_entries+="DNS.$((idx + 1)) = ${domains[$idx]}"$'\n'
done

create_ca() {
  local ca_conf="$tmp_dir/ca-openssl.cnf"

  if [[ -f "$CA_CERT_FILE" && -f "$CA_KEY_FILE" ]]; then
    chown root:root "$CA_CERT_FILE" "$CA_KEY_FILE"
    chmod 0644 "$CA_CERT_FILE"
    chmod 0600 "$CA_KEY_FILE"
    log "existing internal CA found; reusing $CA_CERT_FILE"
    return 0
  fi

  if [[ -e "$CA_CERT_FILE" || -e "$CA_KEY_FILE" ]]; then
    die "internal CA is incomplete; expected both $CA_CERT_FILE and $CA_KEY_FILE"
  fi

  {
    printf '[req]\n'
    printf 'default_bits = 4096\n'
    printf 'prompt = no\n'
    printf 'default_md = sha256\n'
    printf 'distinguished_name = dn\n'
    printf 'x509_extensions = v3_ca\n\n'
    printf '[dn]\n'
    printf 'CN = Lab Platform Internal Root CA\n'
    printf 'O = Lab Platform\n\n'
    printf '[v3_ca]\n'
    printf 'subjectKeyIdentifier = hash\n'
    printf 'authorityKeyIdentifier = keyid:always,issuer\n'
    printf 'basicConstraints = critical, CA:TRUE, pathlen:0\n'
    printf 'keyUsage = critical, keyCertSign, cRLSign\n'
  } >"$ca_conf"

  openssl req -x509 -nodes -newkey rsa:4096 -sha256 \
    -days "$CA_VALID_DAYS" \
    -keyout "$CA_KEY_FILE" \
    -out "$CA_CERT_FILE" \
    -config "$ca_conf"
  chown root:root "$CA_CERT_FILE" "$CA_KEY_FILE"
  chmod 0644 "$CA_CERT_FILE"
  chmod 0600 "$CA_KEY_FILE"
  log "created internal CA at $CA_CERT_FILE"
}

create_leaf() {
  local csr_conf="$tmp_dir/leaf-csr.cnf"
  local ext_conf="$tmp_dir/leaf-ext.cnf"
  local leaf_key="$tmp_dir/origin.key"
  local leaf_csr="$tmp_dir/origin.csr"
  local leaf_crt="$tmp_dir/origin.crt"
  local chain_crt="$tmp_dir/origin-chain.crt"
  local serial

  {
    printf '[req]\n'
    printf 'default_bits = 4096\n'
    printf 'prompt = no\n'
    printf 'default_md = sha256\n'
    printf 'distinguished_name = dn\n\n'
    printf '[dn]\n'
    printf 'CN = %s\n' "${AUTH_DOMAIN:-auth.lab.snu.ac.kr}"
    printf 'O = Lab Platform\n'
  } >"$csr_conf"

  {
    printf '[v3_server]\n'
    printf 'subjectKeyIdentifier = hash\n'
    printf 'authorityKeyIdentifier = keyid,issuer\n'
    printf 'basicConstraints = critical, CA:FALSE\n'
    printf 'keyUsage = critical, digitalSignature, keyEncipherment\n'
    printf 'extendedKeyUsage = serverAuth\n'
    printf 'subjectAltName = @alt_names\n\n'
    printf '[alt_names]\n'
    printf '%s' "$san_entries"
  } >"$ext_conf"

  openssl genrsa -out "$leaf_key" 4096
  openssl req -new -key "$leaf_key" -out "$leaf_csr" -config "$csr_conf"
  serial="0x$(openssl rand -hex 16)"
  openssl x509 -req \
    -in "$leaf_csr" \
    -CA "$CA_CERT_FILE" \
    -CAkey "$CA_KEY_FILE" \
    -set_serial "$serial" \
    -days "$LEAF_VALID_DAYS" \
    -sha256 \
    -extfile "$ext_conf" \
    -extensions v3_server \
    -out "$leaf_crt"

  cat "$leaf_crt" "$CA_CERT_FILE" >"$chain_crt"

  backup_file "$CERT_FILE"
  backup_file "$KEY_FILE"
  install -o root -g root -m 0644 "$chain_crt" "$CERT_FILE"
  install -o root -g root -m 0600 "$leaf_key" "$KEY_FILE"
  log "created CA-signed origin certificate chain at $CERT_FILE"
}

update_lab_ca_bundle() {
  local bundle_dir tmp_bundle

  bundle_dir="$(dirname "$LAB_CA_BUNDLE_FILE")"
  install -d -m 0750 "$bundle_dir"
  tmp_bundle="$(mktemp "$bundle_dir/ca-certificates.crt.XXXXXX")"

  if [[ -f "$SYSTEM_CA_BUNDLE_FILE" ]]; then
    cat "$SYSTEM_CA_BUNDLE_FILE" "$CA_CERT_FILE" >"$tmp_bundle"
  else
    cp "$CA_CERT_FILE" "$tmp_bundle"
  fi

  install -m 0644 "$tmp_bundle" "$LAB_CA_BUNDLE_FILE"
  rm -f "$tmp_bundle"
  log "updated lab CA bundle at $LAB_CA_BUNDLE_FILE"
}

create_ca
create_leaf
update_lab_ca_bundle

chown root:root "$CERT_DIR" "$CA_CERT_FILE" "$CA_KEY_FILE" "$CERT_FILE" "$KEY_FILE"
chmod 0700 "$CERT_DIR"
chmod 0644 "$CA_CERT_FILE" "$CERT_FILE"
chmod 0600 "$CA_KEY_FILE" "$KEY_FILE"

log "internal CA TLS files are ready in $CERT_DIR"
