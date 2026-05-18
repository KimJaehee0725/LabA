#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/35-minio-storage.env"

require_cmd docker

MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"
MINIO_STORAGE_BUCKET_MODELS="${MINIO_STORAGE_BUCKET_MODELS:-lab-models}"
MINIO_STORAGE_BUCKET_DATASETS="${MINIO_STORAGE_BUCKET_DATASETS:-lab-datasets}"
MINIO_STORAGE_BUCKET_ARTIFACTS="${MINIO_STORAGE_BUCKET_ARTIFACTS:-lab-artifacts}"
MINIO_STORAGE_BUCKET_PUBLIC="${MINIO_STORAGE_BUCKET_PUBLIC:-lab-public}"
MINIO_STORAGE_BUCKET_BACKUPS="${MINIO_STORAGE_BUCKET_BACKUPS:-lab-backups}"
MINIO_STORAGE_BUCKETS="${MINIO_STORAGE_BUCKETS:-${MINIO_STORAGE_BUCKET_MODELS},${MINIO_STORAGE_BUCKET_DATASETS},${MINIO_STORAGE_BUCKET_ARTIFACTS},${MINIO_STORAGE_BUCKET_PUBLIC},${MINIO_STORAGE_BUCKET_BACKUPS}}"
MINIO_STORAGE_VERSIONING_BUCKETS="${MINIO_STORAGE_VERSIONING_BUCKETS:-$MINIO_STORAGE_BUCKETS}"
MINIO_STORAGE_MEMBER_RW_BUCKETS="${MINIO_STORAGE_MEMBER_RW_BUCKETS:-${MINIO_STORAGE_BUCKET_MODELS},${MINIO_STORAGE_BUCKET_DATASETS},${MINIO_STORAGE_BUCKET_ARTIFACTS},${MINIO_STORAGE_BUCKET_PUBLIC}}"
MINIO_STORAGE_HF_UI_RW_BUCKETS="${MINIO_STORAGE_HF_UI_RW_BUCKETS:-$MINIO_STORAGE_MEMBER_RW_BUCKETS}"
MINIO_POLICY_MEMBER_RW="${MINIO_POLICY_MEMBER_RW:-lab-storage-member-rw}"
MINIO_POLICY_PUBLIC_READ="${MINIO_POLICY_PUBLIC_READ:-lab-public-read}"
MINIO_POLICY_HF_UI_RW="${MINIO_POLICY_HF_UI_RW:-hf-ui-storage-rw}"

split_csv() {
  local value="$1"
  local item
  SPLIT_RESULT=()
  IFS=',' read -r -a _split_items <<<"$value"
  for item in "${_split_items[@]}"; do
    item="${item//[[:space:]]/}"
    [[ -n "$item" ]] || continue
    SPLIT_RESULT+=("$item")
  done
}

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
  if is_placeholder "$value"; then
    die "$name must be set in $ENV_DIR before bootstrapping MinIO storage"
  fi
}

validate_alias() {
  [[ "$MINIO_ALIAS" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "MINIO_ALIAS must be a valid MC_HOST suffix"
}

validate_bucket_name() {
  local bucket="$1"
  [[ "$bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || die "invalid MinIO bucket name: $bucket"
  [[ "$bucket" != *".."* && "$bucket" != *".-"* && "$bucket" != *"-."* ]] || die "invalid MinIO bucket name: $bucket"
}

validate_policy_name() {
  local policy="$1"
  [[ "$policy" =~ ^[A-Za-z0-9+=,.@_-]+$ ]] || die "invalid MinIO policy name: $policy"
}

bucket_in_list() {
  local needle="$1"
  shift
  local bucket
  for bucket in "$@"; do
    [[ "$bucket" == "$needle" ]] && return 0
  done
  return 1
}

json_array() {
  local first=true
  local value
  for value in "$@"; do
    if [[ "$first" == "true" ]]; then
      first=false
    else
      printf ', '
    fi
    printf '"%s"' "$value"
  done
}

bucket_arns() {
  local bucket
  for bucket in "$@"; do
    printf 'arn:aws:s3:::%s\n' "$bucket"
  done
}

object_arns() {
  local bucket
  for bucket in "$@"; do
    printf 'arn:aws:s3:::%s/*\n' "$bucket"
  done
}

write_rw_policy() {
  local file="$1"
  shift
  local buckets=("$@")
  local bucket_resources object_resources
  mapfile -t bucket_resources < <(bucket_arns "${buckets[@]}")
  mapfile -t object_resources < <(object_arns "${buckets[@]}")

  {
    printf '{\n'
    printf '  "Version": "2012-10-17",\n'
    printf '  "Statement": [\n'
    printf '    {\n'
    printf '      "Effect": "Allow",\n'
    printf '      "Action": ["s3:ListAllMyBuckets"],\n'
    printf '      "Resource": ["arn:aws:s3:::*"]\n'
    printf '    },\n'
    printf '    {\n'
    printf '      "Effect": "Allow",\n'
    printf '      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],\n'
    printf '      "Resource": ['
    json_array "${bucket_resources[@]}"
    printf ']\n'
    printf '    },\n'
    printf '    {\n'
    printf '      "Effect": "Allow",\n'
    printf '      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"],\n'
    printf '      "Resource": ['
    json_array "${object_resources[@]}"
    printf ']\n'
    printf '    }\n'
    printf '  ]\n'
    printf '}\n'
  } >"$file"
}

write_read_policy() {
  local file="$1"
  local bucket="$2"
  {
    printf '{\n'
    printf '  "Version": "2012-10-17",\n'
    printf '  "Statement": [\n'
    printf '    {\n'
    printf '      "Effect": "Allow",\n'
    printf '      "Action": ["s3:GetBucketLocation", "s3:ListBucket"],\n'
    printf '      "Resource": ["arn:aws:s3:::%s"]\n' "$bucket"
    printf '    },\n'
    printf '    {\n'
    printf '      "Effect": "Allow",\n'
    printf '      "Action": ["s3:GetObject"],\n'
    printf '      "Resource": ["arn:aws:s3:::%s/*"]\n' "$bucket"
    printf '    }\n'
    printf '  ]\n'
    printf '}\n'
  } >"$file"
}

run_mc() {
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
  local policy="$1"
  local file="$2"
  if is_dry_run; then
    run_mc admin policy create "$MINIO_ALIAS" "$policy" "/policies/$file"
    return 0
  fi
  if run_mc admin policy info "$MINIO_ALIAS" "$policy" >/dev/null 2>&1; then
    log "minio policy exists: $policy"
  else
    run_mc admin policy create "$MINIO_ALIAS" "$policy" "/policies/$file"
  fi
}

validate_alias
validate_policy_name "$MINIO_POLICY_MEMBER_RW"
validate_policy_name "$MINIO_POLICY_PUBLIC_READ"
validate_policy_name "$MINIO_POLICY_HF_UI_RW"

if ! is_dry_run; then
  require_runtime_secret MINIO_ROOT_USER
  require_runtime_secret MINIO_ROOT_PASSWORD
fi

split_csv "$MINIO_STORAGE_BUCKETS"
storage_buckets=("${SPLIT_RESULT[@]}")
split_csv "$MINIO_STORAGE_VERSIONING_BUCKETS"
versioning_buckets=("${SPLIT_RESULT[@]}")
split_csv "$MINIO_STORAGE_MEMBER_RW_BUCKETS"
member_rw_buckets=("${SPLIT_RESULT[@]}")
split_csv "$MINIO_STORAGE_HF_UI_RW_BUCKETS"
hf_ui_rw_buckets=("${SPLIT_RESULT[@]}")

((${#storage_buckets[@]} > 0)) || die "MINIO_STORAGE_BUCKETS must contain at least one bucket"
((${#member_rw_buckets[@]} > 0)) || die "MINIO_STORAGE_MEMBER_RW_BUCKETS must contain at least one bucket"
((${#hf_ui_rw_buckets[@]} > 0)) || die "MINIO_STORAGE_HF_UI_RW_BUCKETS must contain at least one bucket"
bucket_in_list "$MINIO_STORAGE_BUCKET_PUBLIC" "${storage_buckets[@]}" || die "MINIO_STORAGE_BUCKET_PUBLIC must be included in MINIO_STORAGE_BUCKETS"

for bucket in "${storage_buckets[@]}" "${versioning_buckets[@]}" "${member_rw_buckets[@]}" "${hf_ui_rw_buckets[@]}"; do
  validate_bucket_name "$bucket"
done

policy_dir="$(mktemp -d)"
trap 'rm -rf "$policy_dir"' EXIT

write_rw_policy "$policy_dir/member-rw.json" "${member_rw_buckets[@]}"
write_rw_policy "$policy_dir/hf-ui-rw.json" "${hf_ui_rw_buckets[@]}"
write_read_policy "$policy_dir/public-read.json" "$MINIO_STORAGE_BUCKET_PUBLIC"

for bucket in "${storage_buckets[@]}"; do
  run_mc mb --ignore-existing "$MINIO_ALIAS/$bucket"
done

for bucket in "${versioning_buckets[@]}"; do
  run_mc version enable "$MINIO_ALIAS/$bucket"
done

ensure_policy "$MINIO_POLICY_MEMBER_RW" member-rw.json
ensure_policy "$MINIO_POLICY_PUBLIC_READ" public-read.json
ensure_policy "$MINIO_POLICY_HF_UI_RW" hf-ui-rw.json

for bucket in "${storage_buckets[@]}"; do
  if [[ "$bucket" == "$MINIO_STORAGE_BUCKET_PUBLIC" ]]; then
    run_mc anonymous set download "$MINIO_ALIAS/$bucket"
  else
    run_mc anonymous set none "$MINIO_ALIAS/$bucket"
  fi
done

log "phase4 MinIO storage buckets, versioning, policies, and public download policy are ready"
