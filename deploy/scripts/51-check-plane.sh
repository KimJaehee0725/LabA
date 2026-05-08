#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/40-plane.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

PLANE_URL="${PLANE_URL:-https://lab.snu.ac.kr}"
COMPOSE_FILE="${LAB_PLATFORM_ROOT}/compose/plane/docker-compose.yml"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
curl_args=(-ksSI)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_args+=(--resolve "$CURL_RESOLVE")
fi
curl_get_args=(-ksS)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_get_args+=(--resolve "$CURL_RESOLVE")
fi

curl "${curl_args[@]}" "$PLANE_URL" >/dev/null
curl "${curl_get_args[@]}" -f "$PLANE_URL/auth/get-csrf-token/" | grep -q '"csrf_token"'
upload_status="$(curl "${curl_get_args[@]}" -o /dev/null -w '%{http_code}' "$PLANE_URL/${PLANE_S3_BUCKET:-plane-uploads}?list-type=2" || true)"
if [[ "$upload_status" != "403" ]]; then
  die "Plane MinIO upload route returned HTTP $upload_status instead of anonymous-denied 403"
fi
docker compose \
  --env-file "$ENV_DIR/00-global.env" \
  --env-file "$ENV_DIR/10-core.env" \
  --env-file "$ENV_DIR/40-plane.env" \
  --env-file "$ENV_DIR/80-minio-policies.env" \
  -f "$COMPOSE_FILE" \
  -p lab_plane ps plane-api plane-worker plane-beat >/dev/null
docker run --rm \
  --network lab_data \
  -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-minioadmin}" \
  -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minioadmin}" \
  --entrypoint /bin/sh \
  "$MINIO_MC_IMAGE" \
  -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
  sh "$MINIO_ALIAS" ls "$MINIO_ALIAS/${PLANE_S3_BUCKET:-plane-uploads}" >/dev/null
echo "plane reachability and process checks passed"
