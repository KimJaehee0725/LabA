#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENABLED_SERVICES="${ENABLED_SERVICES:-core,edge,authentik,gitea,plane,mlflow,nextcloud}"

check_for_service() {
  case "$1" in
    core) printf '%s\n' "04-check-core.sh" ;;
    edge) printf '%s\n' "10-check-edge.sh" ;;
    authentik) printf '%s\n' "20-check-authentik.sh" ;;
    gitea) printf '%s\n' "41-check-gitea.sh" ;;
    plane) printf '%s\n' "51-check-plane.sh" ;;
    mlflow) printf '%s\n' "60-check-mlflow.sh" ;;
    nextcloud|collabora) printf '%s\n' "72-check-nextcloud.sh" ;;
    overleaf) printf '%s\n' "80-check-overleaf.sh" ;;
    *) echo "unknown enabled service: $1" >&2; return 1 ;;
  esac
}

checks=()
IFS=',' read -r -a services <<<"$ENABLED_SERVICES"
for service in "${services[@]}"; do
  service="${service//[[:space:]]/}"
  [[ -n "$service" ]] || continue
  checks+=("$(check_for_service "$service")")
done

for check in "${checks[@]}"; do
  echo "== $check =="
  "$SCRIPT_DIR/$check"
done
