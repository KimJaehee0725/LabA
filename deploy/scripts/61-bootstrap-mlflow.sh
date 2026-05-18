#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_common_args "$@"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/50-mlflow.env"

require_cmd docker

MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MLFLOW_DB_NAME="${MLFLOW_DB_NAME:-mlflow}"
MLFLOW_DB_USER="${MLFLOW_DB_USER:-mlflow_user}"
MLFLOW_S3_BUCKET="${MLFLOW_S3_BUCKET:-${MINIO_STORAGE_BUCKET_ARTIFACTS:-lab-artifacts}}"
MLFLOW_S3_ARTIFACT_PREFIX="${MLFLOW_S3_ARTIFACT_PREFIX:-mlflow}"
MLFLOW_MINIO_POLICY="${MLFLOW_MINIO_POLICY:-mlflow-artifacts-rw}"

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" ||
    "$value" == change-me* ||
    "$value" == CHANGE-ME* ||
    "$value" == todo* ||
    "$value" == TODO* ]]
}

require_runtime_secret() {
  local name="$1"
  local value="${!name:-}"
  if is_dry_run; then
    return 0
  fi
  if is_placeholder "$value"; then
    die "$name must be set in $ENV_DIR before bootstrapping MLflow"
  fi
}

validate_name() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "$label must be a SQL identifier-like value: $value"
}

validate_bucket_name() {
  local bucket="$1"
  [[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || die "invalid MinIO bucket name: $bucket"
}

validate_policy_name() {
  local policy="$1"
  [[ "$policy" =~ ^[A-Za-z0-9+=,.@_-]+$ ]] || die "invalid MinIO policy name: $policy"
}

normalize_prefix() {
  local prefix="$1"
  prefix="${prefix#/}"
  prefix="${prefix%/}"
  [[ -n "$prefix" ]] || die "MLFLOW_S3_ARTIFACT_PREFIX must not be empty"
  printf '%s' "$prefix"
}

run_mc_root() {
  if is_dry_run; then
    printf '+ docker run --rm --network %q -v %q:/policies:ro -e MINIO_ROOT_USER=<redacted> -e MINIO_ROOT_PASSWORD=<redacted> %q mc' \
      "$LABSTACK_DATA_NETWORK" "$policy_dir" "$MINIO_MC_IMAGE"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$policy_dir:/policies:ro" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

ensure_policy() {
  if is_dry_run; then
    run_mc_root admin policy create "$MINIO_ALIAS" "$MLFLOW_MINIO_POLICY" /policies/mlflow-rw.json
    return 0
  fi
  if run_mc_root admin policy info "$MINIO_ALIAS" "$MLFLOW_MINIO_POLICY" >/dev/null 2>&1; then
    log "MinIO policy exists: $MLFLOW_MINIO_POLICY"
  else
    run_mc_root admin policy create "$MINIO_ALIAS" "$MLFLOW_MINIO_POLICY" /policies/mlflow-rw.json
  fi
}

ensure_minio_user() {
  if is_dry_run; then
    printf '+ mc admin user add %q <redacted-access-key> <redacted-secret-key>\n' "$MINIO_ALIAS"
    printf '+ mc admin policy attach %q %q --user <redacted-access-key>\n' "$MINIO_ALIAS" "$MLFLOW_MINIO_POLICY"
    return 0
  fi
  if run_mc_root admin user info "$MINIO_ALIAS" "$MLFLOW_S3_ACCESS_KEY" >/dev/null 2>&1; then
    log "MinIO MLflow service user exists"
  else
    run_mc_root admin user add "$MINIO_ALIAS" "$MLFLOW_S3_ACCESS_KEY" "$MLFLOW_S3_SECRET_KEY"
  fi
  run_mc_root admin policy attach "$MINIO_ALIAS" "$MLFLOW_MINIO_POLICY" --user "$MLFLOW_S3_ACCESS_KEY"
}

bootstrap_postgres() {
  if is_dry_run; then
    printf '+ docker exec postgres psql -U %q -v db_name=%q -v db_user=%q -v db_password=<redacted>\n' \
      "${POSTGRES_USER:-postgres}" "$MLFLOW_DB_NAME" "$MLFLOW_DB_USER"
    return 0
  fi

  docker exec -i postgres psql \
    -v ON_ERROR_STOP=1 \
    -U "${POSTGRES_USER:-postgres}" \
    -v db_name="$MLFLOW_DB_NAME" \
    -v db_user="$MLFLOW_DB_USER" \
    -v db_password="$MLFLOW_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'db_user', :'db_password')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'db_user')\gexec
SQL
}

validate_name MLFLOW_DB_NAME "$MLFLOW_DB_NAME"
validate_name MLFLOW_DB_USER "$MLFLOW_DB_USER"
validate_bucket_name "$MLFLOW_S3_BUCKET"
validate_policy_name "$MLFLOW_MINIO_POLICY"
MLFLOW_S3_ARTIFACT_PREFIX="$(normalize_prefix "$MLFLOW_S3_ARTIFACT_PREFIX")"

require_runtime_secret MLFLOW_DB_PASSWORD
require_runtime_secret MINIO_ROOT_USER
require_runtime_secret MINIO_ROOT_PASSWORD
require_runtime_secret MLFLOW_S3_ACCESS_KEY
require_runtime_secret MLFLOW_S3_SECRET_KEY

policy_dir="$(mktemp -d)"
trap 'rm -rf "$policy_dir"' EXIT

cat >"$policy_dir/mlflow-rw.json" <<EOF_POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListAllMyBuckets"],
      "Resource": ["arn:aws:s3:::*"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": ["arn:aws:s3:::${MLFLOW_S3_BUCKET}"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],
      "Resource": ["arn:aws:s3:::${MLFLOW_S3_BUCKET}/${MLFLOW_S3_ARTIFACT_PREFIX}/*"]
    }
  ]
}
EOF_POLICY

bootstrap_postgres
run_mc_root mb --ignore-existing "$MINIO_ALIAS/$MLFLOW_S3_BUCKET"
ensure_policy
ensure_minio_user

log "Phase 8 MLflow Postgres DB/user and MinIO artifact access are ready"
