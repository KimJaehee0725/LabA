#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/50-mlflow.env"

require_cmd curl
require_cmd docker

MLFLOW_URL="${MLFLOW_URL:-https://${MLFLOW_DOMAIN:-mlflow.lab.snu.ac.kr}}"
MLFLOW_INTERNAL_URL="${MLFLOW_INTERNAL_URL:-http://127.0.0.1:5000}"
MLFLOW_CONTAINER="${MLFLOW_CONTAINER:-mlflow}"
MLFLOW_CA_CERT="${MLFLOW_CA_CERT:-$LAB_PLATFORM_ROOT/nginx/ssl/lab-internal-ca.crt}"

curl_probe_args=(-sS -o /dev/null -w '%{http_code}' -I)
curl_follow_args=(-sSfL)
if [[ "${CURL_RESOLVE:-}" != "" ]]; then
  curl_probe_args+=(--resolve "$CURL_RESOLVE")
  curl_follow_args+=(--resolve "$CURL_RESOLVE")
fi
if [[ -f "$MLFLOW_CA_CERT" ]]; then
  curl_probe_args+=(--cacert "$MLFLOW_CA_CERT")
  curl_follow_args+=(--cacert "$MLFLOW_CA_CERT")
else
  curl_probe_args+=(-k)
  curl_follow_args+=(-k)
fi

status="$(curl "${curl_probe_args[@]}" "$MLFLOW_URL" || true)"
case "$status" in
  302|401|403) echo "mlflow external auth gate returned $status" ;;
  *) echo "unexpected unauthenticated MLflow status: $status" >&2; exit 1 ;;
esac

docker exec -i \
  -e "MLFLOW_INTERNAL_URL=${MLFLOW_INTERNAL_URL}" \
  "$MLFLOW_CONTAINER" python - <<'PY'
import os
import requests

r = requests.get(os.environ["MLFLOW_INTERNAL_URL"], timeout=10)
r.raise_for_status()
PY

if [[ "${MLFLOW_SKIP_ARTIFACT_SMOKE:-false}" != "true" ]]; then
  "$SCRIPT_DIR/61-smoke-mlflow-artifact.sh"
fi

echo "mlflow checks passed"
