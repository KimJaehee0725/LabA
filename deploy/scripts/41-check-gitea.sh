#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/30-gitea.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

GITEA_URL="${GITEA_URL:-https://hub.lab.snu.ac.kr}"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
curl_args=(-ksSf)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_args+=(--resolve "$CURL_RESOLVE")
fi

curl "${curl_args[@]}" "$GITEA_URL/api/v1/version" >/dev/null
docker exec --user git gitea gitea doctor check --config /data/gitea/conf/app.ini >/dev/null
docker run --rm \
  --network lab_data \
  -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}" \
  -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}" \
  --entrypoint /bin/sh \
  "$MINIO_MC_IMAGE" \
  -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
  sh "$MINIO_ALIAS" ls "$MINIO_ALIAS/${GITEA_LFS_BUCKET:-gitea-lfs}" >/dev/null
echo "gitea checks passed"
