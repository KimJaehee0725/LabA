#!/usr/bin/env bash
set -euo pipefail

OVERLEAF_URL="${OVERLEAF_URL:-https://papers.lab.snu.ac.kr}"

curl -ksSI "$OVERLEAF_URL" >/dev/null
docker exec overleaf node --version >/dev/null
docker exec overleaf bash -lc 'command -v latexmk >/dev/null'
docker exec overleaf-mongo mongosh --quiet --eval 'db.adminCommand({ ping: 1 }).ok' | grep -q 1
echo "overleaf checks passed"
