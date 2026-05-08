#!/usr/bin/env bash
set -euo pipefail

docker exec nginx nginx -t

if [[ "${ALLOW_GITEA_SSH:-false}" == "true" ]]; then
  bad_port_pattern='^(5432|6379|9000|9001|9980|3000|5000|8000)$'
else
  bad_port_pattern='^(2222|5432|6379|9000|9001|9980|3000|5000|8000)$'
fi

ports="$(ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://')"
bad="$(printf '%s\n' "$ports" | grep -E "$bad_port_pattern" || true)"
if [[ -n "$bad" ]]; then
  echo "unexpected public service ports: $bad" >&2
  exit 1
fi

echo "edge checks passed"
