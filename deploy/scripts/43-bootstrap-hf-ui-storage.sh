#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/45-hf-ui.env"

require_cmd docker

MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_POLICY_HF_UI_RW="${MINIO_POLICY_HF_UI_RW:-hf-ui-storage-rw}"
HF_UI_MODELS_BUCKET="${HF_UI_MODELS_BUCKET:-lab-models}"
HF_UI_DATASETS_BUCKET="${HF_UI_DATASETS_BUCKET:-lab-datasets}"
HF_UI_IMAGE="${HF_UI_IMAGE:-lab/hf-ui:phase5}"
HF_UI_PUBLIC_URL="${HF_UI_PUBLIC_URL:-https://${HF_DOMAIN:-hf.lab.example.ac.kr}}"
HF_UI_PUBLIC_URL="${HF_UI_PUBLIC_URL%/}"

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" ||
    "$value" == change-me* ||
    "$value" == CHANGE-ME* ||
    "$value" == todo* ||
    "$value" == TODO* ]]
}

require_secret() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    die "$name must be set in $ENV_DIR/45-hf-ui.env before bootstrapping HF UI storage"
  fi
}

run_mc_root() {
  docker run --rm -i \
    --network "$LABSTACK_DATA_NETWORK" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

run_mc_hf() {
  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$sample_dir:/samples:ro" \
    -e "HF_UI_S3_ACCESS_KEY=${HF_UI_S3_ACCESS_KEY:-}" \
    -e "HF_UI_S3_SECRET_KEY=${HF_UI_S3_SECRET_KEY:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$HF_UI_S3_ACCESS_KEY" "$HF_UI_S3_SECRET_KEY" >/dev/null; shift; exec mc "$@"' \
    sh hfui "$@"
}

run_hf_ui_python() {
  docker run --rm -i \
    --user 0:0 \
    -v "$sample_dir:/samples" \
    --entrypoint python \
    "$HF_UI_IMAGE" "$@"
}

configure_bucket_cors() {
  local bucket="$1"
  if run_mc_root cors set "$MINIO_ALIAS/$bucket" - <"$sample_dir/hf-ui-cors.xml"; then
    log "MinIO CORS configured for bucket: $bucket"
  else
    log "MinIO bucket CORS API is unavailable; constraining server CORS origin to $HF_UI_PUBLIC_URL"
    run_mc_root admin config set "$MINIO_ALIAS/" api "cors_allow_origin=${HF_UI_PUBLIC_URL}"
  fi
}

require_secret MINIO_ROOT_USER
require_secret MINIO_ROOT_PASSWORD
require_secret HF_UI_S3_ACCESS_KEY
require_secret HF_UI_S3_SECRET_KEY

sample_dir="$(mktemp -d)"
trap 'rm -rf "$sample_dir"' EXIT
mkdir -p "$sample_dir/model" "$sample_dir/dataset"

cat >"$sample_dir/hf-ui-cors.xml" <<EOF_CORS
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>${HF_UI_PUBLIC_URL}</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <MaxAgeSeconds>3600</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
EOF_CORS

cat >"$sample_dir/model/README.md" <<'EOF_MODEL_README'
# Tiny Transformer Demo

This model bundle validates the Phase 5 HF-like UI catalog and MinIO file tree.

```python
print("hello from the lab model catalog")
```
EOF_MODEL_README
cat >"$sample_dir/model/config.json" <<'EOF_MODEL_CONFIG'
{"architectures":["TinyTransformer"],"hidden_size":16,"num_attention_heads":2}
EOF_MODEL_CONFIG
cat >"$sample_dir/model/model.safetensors" <<'EOF_MODEL_WEIGHTS'
phase5 demo weights placeholder
EOF_MODEL_WEIGHTS

cat >"$sample_dir/dataset/README.md" <<'EOF_DATASET_README'
# Sentiment Mini Dataset

Small multi-format dataset for Phase 5 list, detail, README, file tree, download,
and dataset preview smoke.

- task: text-classification
- splits: train.jsonl, validation.csv, test.json, sample.parquet
EOF_DATASET_README
cat >"$sample_dir/dataset/train.jsonl" <<'EOF_DATASET_ROWS'
{"text":"great result with a detailed annotation for preview length stats","label":"positive","reviewed":true}
{"text":"needs work before sharing with collaborators","label":"negative","reviewed":false}
{"text":"neutral example with enough text to exercise long string buckets","label":"neutral","reviewed":true}
{"text":"great result with a detailed annotation for preview length stats","label":"positive","reviewed":true}
EOF_DATASET_ROWS
cat >"$sample_dir/dataset/validation.csv" <<'EOF_DATASET_VALIDATION'
id,text,label,score,tokens,accepted
1,held-out positive sample,positive,0.91,11,true
2,held-out negative sample,negative,0.18,9,false
3,held-out neutral sample,neutral,0.52,10,true
EOF_DATASET_VALIDATION
cat >"$sample_dir/dataset/test.json" <<'EOF_DATASET_TEST'
{
  "rows": [
    {"id": "test-1", "text": "compact positive test row", "label": "positive"},
    {"id": "test-2", "text": "compact negative test row", "label": "negative"}
  ]
}
EOF_DATASET_TEST
run_hf_ui_python - <<'PY'
import pyarrow as pa
import pyarrow.parquet as pq

table = pa.table(
    {
        "id": pa.array([1, 2, 3, 4], type=pa.int64()),
        "text": pa.array(
            [
                "parquet positive training row with a longer review body",
                "parquet negative training row",
                "parquet neutral row with numeric confidence",
                "parquet positive follow-up row",
            ],
            type=pa.string(),
        ),
        "label": pa.array(["positive", "negative", "neutral", "positive"], type=pa.string()),
        "score": pa.array([0.97, 0.12, 0.55, 0.88], type=pa.float64()),
        "tokens": pa.array([14, 8, 11, 9], type=pa.int64()),
        "reviewed": pa.array([True, False, True, True], type=pa.bool_()),
    }
)
pq.write_table(table, "/samples/dataset/sample.parquet", compression="snappy")
PY

if run_mc_root admin user info "$MINIO_ALIAS" "$HF_UI_S3_ACCESS_KEY" >/dev/null 2>&1; then
  log "MinIO HF UI service user exists"
else
  run_mc_root admin user add "$MINIO_ALIAS" "$HF_UI_S3_ACCESS_KEY" "$HF_UI_S3_SECRET_KEY"
fi
run_mc_root admin policy attach "$MINIO_ALIAS" "$MINIO_POLICY_HF_UI_RW" --user "$HF_UI_S3_ACCESS_KEY"
configure_bucket_cors "$HF_UI_MODELS_BUCKET"
configure_bucket_cors "$HF_UI_DATASETS_BUCKET"

run_mc_hf cp --recursive /samples/model/ "hfui/$HF_UI_MODELS_BUCKET/demo/tiny-transformer/v1/"
run_mc_hf cp --recursive /samples/dataset/ "hfui/$HF_UI_DATASETS_BUCKET/demo/sentiment-mini/v1/"

log "phase5 HF UI service user, bucket CORS, and sample MinIO objects are ready"
