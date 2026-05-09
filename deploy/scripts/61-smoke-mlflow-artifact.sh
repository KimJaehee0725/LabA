#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/80-minio-policies.env" \
  "$ENV_DIR/50-mlflow.env"

require_cmd docker
require_cmd jq

MLFLOW_CONTAINER="${MLFLOW_CONTAINER:-mlflow}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_ALIAS="${MINIO_ALIAS:-labmlflow}"
MLFLOW_S3_BUCKET="${MLFLOW_S3_BUCKET:-${MINIO_BUCKET_MLFLOW:-mlflow-artifacts}}"
MLFLOW_INTERNAL_TRACKING_URI="${MLFLOW_INTERNAL_TRACKING_URI:-http://127.0.0.1:5000}"
MLFLOW_SMOKE_EXPERIMENT="${MLFLOW_SMOKE_EXPERIMENT:-lab-platform-smoke}"

if [[ -z "${MLFLOW_S3_ACCESS_KEY:-}" || -z "${MLFLOW_S3_SECRET_KEY:-}" || "${MLFLOW_S3_ACCESS_KEY:-}" == change-me* || "${MLFLOW_S3_SECRET_KEY:-}" == change-me* ]]; then
  die "MLFLOW_S3_ACCESS_KEY and MLFLOW_S3_SECRET_KEY must be configured before artifact smoke"
fi
export MLFLOW_S3_ACCESS_KEY MLFLOW_S3_SECRET_KEY

smoke_output="$(
  docker exec -i \
    -e "MLFLOW_INTERNAL_TRACKING_URI=${MLFLOW_INTERNAL_TRACKING_URI}" \
    -e "MLFLOW_SMOKE_EXPERIMENT=${MLFLOW_SMOKE_EXPERIMENT}" \
    -e GIT_PYTHON_REFRESH=quiet \
    "$MLFLOW_CONTAINER" python - <<'PY'
import json
import os
import tempfile
import time

import mlflow

tracking_uri = os.environ["MLFLOW_INTERNAL_TRACKING_URI"]
experiment_name = os.environ["MLFLOW_SMOKE_EXPERIMENT"]
mlflow.set_tracking_uri(tracking_uri)
experiment = mlflow.set_experiment(experiment_name)

with mlflow.start_run(run_name=f"v0.3-smoke-{int(time.time())}") as run:
    mlflow.log_param("platform_wave", "v0.3-mlflow-nextcloud-app")
    mlflow.log_metric("smoke_ok", 1.0)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".json", delete=False) as handle:
        json.dump(
            {
                "platform_wave": "v0.3-mlflow-nextcloud-app",
                "smoke_ok": True,
                "run_id": run.info.run_id,
            },
            handle,
            sort_keys=True,
        )
        handle.write("\n")
        artifact_path = handle.name
    try:
        mlflow.log_artifact(artifact_path, artifact_path="smoke")
    finally:
        try:
            os.remove(artifact_path)
        except FileNotFoundError:
            pass
    print(json.dumps({
        "experiment_id": experiment.experiment_id,
        "run_id": run.info.run_id,
        "artifact_file": os.path.basename(artifact_path),
    }))
PY
)"
smoke_json="$(awk '/^\{.*\}$/ { line = $0 } END { if (line == "") exit 1; print line }' <<<"$smoke_output")"

run_id="$(jq -er '.run_id' <<<"$smoke_json")"
artifact_file="$(jq -er '.artifact_file' <<<"$smoke_json")"

db_count="$(
  docker exec "$POSTGRES_CONTAINER" psql \
    -U "${POSTGRES_USER:-postgres}" \
    -d "${MLFLOW_DB_NAME:-mlflow}" \
    -tAc "select count(*) from runs where run_uuid = '$run_id';"
)"
if [[ "$db_count" != "1" ]]; then
  die "MLflow run metadata was not found in Postgres for run $run_id"
fi

run_mc() {
  docker run --rm \
    --network lab_data \
    -e MLFLOW_S3_ACCESS_KEY \
    -e MLFLOW_S3_SECRET_KEY \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MLFLOW_S3_ACCESS_KEY" "$MLFLOW_S3_SECRET_KEY" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

if ! run_mc ls --recursive "$MINIO_ALIAS/$MLFLOW_S3_BUCKET" | grep -F "$run_id" | grep -F "$artifact_file" >/dev/null; then
  die "MLflow artifact object for run $run_id was not found in MinIO bucket $MLFLOW_S3_BUCKET"
fi

echo "mlflow artifact smoke passed for run $run_id"
