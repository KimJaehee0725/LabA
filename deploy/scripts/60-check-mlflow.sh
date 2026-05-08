#!/usr/bin/env bash
set -euo pipefail

MLFLOW_URL="${MLFLOW_URL:-https://mlflow.lab.snu.ac.kr}"

status="$(curl -ksSI "$MLFLOW_URL" | awk 'NR == 1 {print $2}')"
case "$status" in
  302|401|403) echo "mlflow external auth gate returned $status" ;;
  *) echo "unexpected unauthenticated MLflow status: $status" >&2; exit 1 ;;
esac

docker exec mlflow python - <<'PY'
import requests
r = requests.get("http://127.0.0.1:5000", timeout=10)
r.raise_for_status()
PY
echo "mlflow checks passed"
