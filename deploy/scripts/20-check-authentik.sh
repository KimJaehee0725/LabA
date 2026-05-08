#!/usr/bin/env bash
set -euo pipefail

AUTH_URL="${AUTH_URL:-https://auth.lab.snu.ac.kr}"

docker compose -p lab_authentik ps
curl -ksSf "$AUTH_URL/application/o/.well-known/openid-configuration" >/dev/null || \
  curl -ksSf "$AUTH_URL/if/flow/initial-setup/" >/dev/null
echo "authentik reachability check passed"
