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
    printf '+ docker run --rm --network lab_data -v %q:/policies:ro -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc' \
      "$LAB_PLATFORM_ROOT/minio/policies" "$MINIO_MC_IMAGE"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  docker run --rm \
    --network lab_data \
    -v "$LAB_PLATFORM_ROOT/minio/policies:/policies:ro" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

ensure_policy() {
  local policy="$1"
  local file="$2"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    run_mc admin policy create "$MINIO_ALIAS" "$policy" "$file"
    return 0
  fi

  if run_mc admin policy info "$MINIO_ALIAS" "$policy" >/dev/null 2>&1; then
    log "minio policy exists: $policy"
  else
    run_mc admin policy create "$MINIO_ALIAS" "$policy" "$file"
  fi
}

for bucket in "${MINIO_BUCKET_PLANE:-plane-uploads}" "${MINIO_BUCKET_GITEA_LFS:-gitea-lfs}" "${MINIO_BUCKET_MLFLOW:-mlflow-artifacts}" "${MINIO_BUCKET_BACKUPS:-backups}"; do
  run_mc mb --ignore-existing "$MINIO_ALIAS/$bucket"
done

ensure_policy "${MINIO_POLICY_PLANE:-plane-uploads-rw}" /policies/plane-uploads-rw.json
ensure_policy "${MINIO_POLICY_GITEA_LFS:-gitea-lfs-rw}" /policies/gitea-lfs-rw.json
ensure_policy "${MINIO_POLICY_MLFLOW:-mlflow-artifacts-rw}" /policies/mlflow-artifacts-rw.json

log "create service access keys on the server and store them in /srv/lab-platform/env; do not paste generated secrets into git or history"
