#!/usr/bin/env bash
set -euo pipefail

GITEA_CONTAINER="${GITEA_CONTAINER:-gitea}"
ORG_FILE="${ORG_FILE:-/tmp/lab-gitea-orgs.txt}"

cat >"$ORG_FILE" <<'ORG'
lab-code
lab-models
lab-datasets
lab-papers
ORG

echo "Create these private organizations after first admin/OIDC login:"
cat "$ORG_FILE"
echo "Use the Gitea UI or admin CLI with a server-side token; do not store tokens in this repository."
docker exec "$GITEA_CONTAINER" gitea --version
