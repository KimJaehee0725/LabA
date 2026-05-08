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
MINIO_MC_HOST="MC_HOST_${MINIO_ALIAS}=http://${MINIO_ROOT_USER:-minioadmin}:${MINIO_ROOT_PASSWORD:-minioadmin}@minio:9000"

run_mc() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    printf '+ docker run --rm --network lab_data -v %q:/policies:ro -e MC_HOST_%s=<redacted> %q' \
      "$LAB_PLATFORM_ROOT/minio/policies" "$MINIO_ALIAS" "$MINIO_MC_IMAGE"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  docker run --rm \
    --network lab_data \
    -v "$LAB_PLATFORM_ROOT/minio/policies:/policies:ro" \
    -e "$MINIO_MC_HOST" \
    "$MINIO_MC_IMAGE" \
    "$@"
}

for bucket in "${MINIO_BUCKET_PLANE:-plane-uploads}" "${MINIO_BUCKET_GITEA_LFS:-gitea-lfs}" "${MINIO_BUCKET_MLFLOW:-mlflow-artifacts}" "${MINIO_BUCKET_BACKUPS:-backups}"; do
  run_mc mb --ignore-existing "$MINIO_ALIAS/$bucket"
done

run_mc admin policy create "$MINIO_ALIAS" "${MINIO_POLICY_PLANE:-plane-uploads-rw}" /policies/plane-uploads-rw.json
run_mc admin policy create "$MINIO_ALIAS" "${MINIO_POLICY_GITEA_LFS:-gitea-lfs-rw}" /policies/gitea-lfs-rw.json
run_mc admin policy create "$MINIO_ALIAS" "${MINIO_POLICY_MLFLOW:-mlflow-artifacts-rw}" /policies/mlflow-artifacts-rw.json

log "create service access keys on the server and store them in /srv/lab-platform/env; do not paste generated secrets into git or history"
