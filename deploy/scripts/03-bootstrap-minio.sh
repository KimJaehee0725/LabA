#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

MC=(docker run --rm --network lab_data -v "$LAB_PLATFORM_ROOT/minio/policies:/policies:ro" "${MINIO_MC_IMAGE:-minio/mc:latest}")

run_cmd "${MC[@]}" alias set local http://minio:9000 "${MINIO_ROOT_USER:-minioadmin}" "${MINIO_ROOT_PASSWORD:-minioadmin}"

for bucket in "${MINIO_BUCKET_PLANE:-plane-uploads}" "${MINIO_BUCKET_GITEA_LFS:-gitea-lfs}" "${MINIO_BUCKET_MLFLOW:-mlflow-artifacts}" "${MINIO_BUCKET_BACKUPS:-backups}"; do
  run_cmd "${MC[@]}" mb --ignore-existing "local/$bucket"
done

run_cmd "${MC[@]}" admin policy create local "${MINIO_POLICY_PLANE:-plane-uploads-rw}" /policies/plane-uploads-rw.json
run_cmd "${MC[@]}" admin policy create local "${MINIO_POLICY_GITEA_LFS:-gitea-lfs-rw}" /policies/gitea-lfs-rw.json
run_cmd "${MC[@]}" admin policy create local "${MINIO_POLICY_MLFLOW:-mlflow-artifacts-rw}" /policies/mlflow-artifacts-rw.json

log "create service access keys on the server and store them in /srv/lab-platform/env; do not paste generated secrets into git or history"
