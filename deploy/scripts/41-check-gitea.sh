#!/usr/bin/env bash
set -euo pipefail

GITEA_URL="${GITEA_URL:-https://hub.lab.snu.ac.kr}"

curl -ksSf "$GITEA_URL/api/v1/version" >/dev/null
docker exec gitea gitea doctor check --config /data/gitea/conf/app.ini >/dev/null
docker exec minio mc ls "local/${GITEA_LFS_BUCKET:-gitea-lfs}" >/dev/null 2>&1 || true
echo "gitea checks passed"
