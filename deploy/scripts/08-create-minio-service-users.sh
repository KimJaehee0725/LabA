#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
[[ "$MINIO_ALIAS" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "MINIO_ALIAS must be a valid MC_HOST suffix"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"

run_mc() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    printf '+ docker run --rm --network lab_data -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc' "$MINIO_MC_IMAGE"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  docker run --rm \
    --network lab_data \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

ensure_user() {
  local label="$1"
  local access_key="$2"
  local secret_key="$3"
  local policy="$4"

  if [[ -z "$access_key" || -z "$secret_key" || "$access_key" == change-me* || "$secret_key" == change-me* ]]; then
    log "skipping $label MinIO user because its access key or secret key is not configured"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    printf '+ docker run --rm --network lab_data -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc admin user add %q <redacted-access-key> <redacted-secret-key>\n' \
      "$MINIO_MC_IMAGE" "$MINIO_ALIAS"
    printf '+ docker run --rm --network lab_data -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc admin policy attach %q %q --user <redacted-access-key>\n' \
      "$MINIO_MC_IMAGE" "$MINIO_ALIAS" "$policy"
    return 0
  fi

  if run_mc admin user info "$MINIO_ALIAS" "$access_key" >/dev/null 2>&1; then
    log "minio user exists: $label"
  else
    run_mc admin user add "$MINIO_ALIAS" "$access_key" "$secret_key"
  fi
  run_mc admin policy attach "$MINIO_ALIAS" "$policy" --user "$access_key"
}

ensure_user "gitea-lfs" "${GITEA_LFS_ACCESS_KEY:-}" "${GITEA_LFS_SECRET_KEY:-}" "${MINIO_POLICY_GITEA_LFS:-gitea-lfs-rw}"
ensure_user "plane-uploads" "${PLANE_S3_ACCESS_KEY:-}" "${PLANE_S3_SECRET_KEY:-}" "${MINIO_POLICY_PLANE:-plane-uploads-rw}"
ensure_user "mlflow-artifacts" "${MLFLOW_S3_ACCESS_KEY:-}" "${MLFLOW_S3_SECRET_KEY:-}" "${MINIO_POLICY_MLFLOW:-mlflow-artifacts-rw}"
