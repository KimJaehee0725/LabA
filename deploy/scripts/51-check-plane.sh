#!/usr/bin/env bash
set -euo pipefail

PLANE_URL="${PLANE_URL:-https://lab.snu.ac.kr}"

curl -ksSI "$PLANE_URL" >/dev/null
docker compose -p lab_plane ps plane-api plane-worker plane-beat >/dev/null
echo "plane reachability and process checks passed"
