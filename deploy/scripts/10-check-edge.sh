#!/usr/bin/env bash
set -euo pipefail

docker exec nginx nginx -t

ports="$(ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://')"
bad="$(printf '%s\n' "$ports" | grep -E '^(5432|6379|9000|9001|9980|3000|5000|8000)$' || true)"
if [[ -n "$bad" ]]; then
  echo "unexpected public service ports: $bad" >&2
  exit 1
fi

echo "edge checks passed"
