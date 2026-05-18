#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/50-mlflow.env"

require_cmd docker
require_cmd curl

MLFLOW_CONTAINER="${MLFLOW_CONTAINER:-mlflow}"
MLFLOW_PORT="${MLFLOW_PORT:-5000}"
MLFLOW_DOMAIN="${MLFLOW_DOMAIN:-mlflow.lab.example.ac.kr}"
MLFLOW_URL="${MLFLOW_URL:-https://${MLFLOW_DOMAIN}}"
MLFLOW_URL="${MLFLOW_URL%/}"
MLFLOW_COMPOSE_FILE="${MLFLOW_COMPOSE_FILE:-${LAB_STACK_ROOT}/compose/mlflow/docker-compose.yml}"
MLFLOW_DB_NAME="${MLFLOW_DB_NAME:-mlflow}"
MLFLOW_DB_USER="${MLFLOW_DB_USER:-mlflow_user}"
MLFLOW_S3_BUCKET="${MLFLOW_S3_BUCKET:-${MINIO_STORAGE_BUCKET_ARTIFACTS:-lab-artifacts}}"
MLFLOW_S3_ARTIFACT_PREFIX="${MLFLOW_S3_ARTIFACT_PREFIX:-mlflow}"
MLFLOW_SMOKE_EXPERIMENT="${MLFLOW_SMOKE_EXPERIMENT:-phase8-smoke}"
MLFLOW_SMOKE_ARTIFACT_PREFIX="${MLFLOW_SMOKE_ARTIFACT_PREFIX:-smoke/phase8-mlflow}"
MLFLOW_EDGE_ENABLED="${MLFLOW_EDGE_ENABLED:-false}"
PHASE8_REQUIRE_AUTH_GATE="${PHASE8_REQUIRE_AUTH_GATE:-false}"
MINIO_ALIAS="${MINIO_ALIAS:-labminio}"
MINIO_MC_IMAGE="${MINIO_MC_IMAGE:-minio/mc:latest}"

status=0
warnings=0
work_dir=""
smoke_id=""

ok() {
  log "ok: $*"
}

warn() {
  log "warn: $*"
  warnings=$((warnings + 1))
}

fail() {
  log "fail: $*"
  status=1
}

is_true() {
  [[ "${1:-}" == "true" || "${1:-}" == "1" || "${1:-}" == "yes" ]]
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
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set without printing its value"
  fi
}

check_non_placeholder() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder "$value"; then
    fail "$name is unset or still a placeholder"
  else
    ok "$name is set"
  fi
}

normalize_prefix() {
  local prefix="$1"
  prefix="${prefix#/}"
  prefix="${prefix%/}"
  printf '%s' "$prefix"
}

run_mc_root() {
  docker run --rm \
    --network "$LABSTACK_DATA_NETWORK" \
    -v "$work_dir:/work" \
    -e "MINIO_ROOT_USER=${MINIO_ROOT_USER:-}" \
    -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-}" \
    --entrypoint /bin/sh \
    "$MINIO_MC_IMAGE" \
    -c 'mc alias set "$1" http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null; shift; exec mc "$@"' \
    sh "$MINIO_ALIAS" "$@"
}

check_container() {
  local name="$1"
  local state health
  if ! docker inspect "$name" >/dev/null 2>&1; then
    fail "missing container: $name"
    return
  fi
  state="$(docker inspect -f '{{.State.Status}}' "$name")"
  health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$name")"
  if [[ "$state" != "running" ]]; then
    fail "$name is not running: $state"
    return
  fi
  if [[ -n "$health" && "$health" != "healthy" ]]; then
    fail "$name health is $health"
    return
  fi
  ok "$name is running${health:+ and $health}"
}

check_no_host_ports() {
  local name="$1"
  local ports
  ports="$(docker inspect -f '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$name" 2>/dev/null || true)"
  if [[ -n "$ports" ]]; then
    fail "$name publishes host ports: $ports"
  else
    ok "$name publishes no host ports"
  fi
}

check_compose_config() {
  if [[ ! -f "$MLFLOW_COMPOSE_FILE" ]]; then
    fail "missing MLflow compose file: $MLFLOW_COMPOSE_FILE"
    return
  fi
  if docker compose -f "$MLFLOW_COMPOSE_FILE" config >/dev/null; then
    ok "MLflow compose config renders"
  else
    fail "MLflow compose config does not render"
  fi
}

check_postgres_backend() {
  if docker exec postgres psql -U "${POSTGRES_USER:-postgres}" -d "$MLFLOW_DB_NAME" -Atc "select current_user, current_database();" >/dev/null; then
    ok "MLflow Postgres backend database is reachable"
  else
    fail "MLflow Postgres backend database is not reachable"
  fi
}

check_internal_http() {
  if docker exec -i "$MLFLOW_CONTAINER" python - <<PY
import urllib.request
urllib.request.urlopen("http://127.0.0.1:${MLFLOW_PORT}", timeout=10).read(1)
PY
  then
    ok "MLflow internal HTTP endpoint responds"
  else
    fail "MLflow internal HTTP endpoint failed"
  fi
}

check_mlflow_smoke() {
  smoke_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  if docker exec -i \
    -e "MLFLOW_TRACKING_URI=http://127.0.0.1:${MLFLOW_PORT}" \
    -e "MLFLOW_SMOKE_EXPERIMENT=${MLFLOW_SMOKE_EXPERIMENT}" \
    -e "MLFLOW_SMOKE_ARTIFACT_PREFIX=${MLFLOW_SMOKE_ARTIFACT_PREFIX}" \
    -e "MLFLOW_SMOKE_ID=${smoke_id}" \
    -e "GIT_PYTHON_REFRESH=quiet" \
    "$MLFLOW_CONTAINER" python - <<'PY'
import json
import os
import tempfile
from pathlib import Path

import mlflow
from mlflow.tracking import MlflowClient

tracking_uri = os.environ["MLFLOW_TRACKING_URI"]
experiment_name = os.environ["MLFLOW_SMOKE_EXPERIMENT"]
artifact_prefix = os.environ.get("MLFLOW_SMOKE_ARTIFACT_PREFIX", "checks").strip("/")
smoke_id = os.environ["MLFLOW_SMOKE_ID"]

mlflow.set_tracking_uri(tracking_uri)
client = MlflowClient(tracking_uri=tracking_uri)
experiment = client.get_experiment_by_name(experiment_name)
if experiment is None:
    experiment_id = client.create_experiment(experiment_name)
else:
    experiment_id = experiment.experiment_id

with mlflow.start_run(experiment_id=experiment_id, run_name=f"phase8-{smoke_id}") as run:
    mlflow.log_param("phase", "8")
    mlflow.log_metric("smoke", 1.0)
    with tempfile.TemporaryDirectory() as tmp:
        artifact = Path(tmp) / f"phase8-mlflow-smoke-{smoke_id}.json"
        artifact.write_text(json.dumps({"smoke_id": smoke_id}) + "\n", encoding="utf-8")
        mlflow.log_artifact(str(artifact), artifact_path=f"{artifact_prefix}/checks")
    run_id = run.info.run_id

listed = client.search_runs([experiment_id], filter_string=f"tags.mlflow.runName = 'phase8-{smoke_id}'")
if not listed:
    raise SystemExit(f"smoke run was not searchable: {run_id}")
print(run_id)
PY
  then
    ok "MLflow experiment/run/artifact smoke succeeded"
  else
    fail "MLflow experiment/run/artifact smoke failed"
  fi
}

check_minio_artifact_evidence() {
  local prefix
  prefix="$(normalize_prefix "$MLFLOW_S3_ARTIFACT_PREFIX")"
  [[ -n "$smoke_id" ]] || { fail "missing MLflow smoke id for artifact evidence"; return; }
  if run_mc_root ls --recursive "$MINIO_ALIAS/$MLFLOW_S3_BUCKET/$prefix" | grep -F "phase8-mlflow-smoke-${smoke_id}.json" >/dev/null; then
    ok "MLflow smoke artifact exists in MinIO under $MLFLOW_S3_BUCKET/$prefix"
  else
    fail "MLflow smoke artifact was not found in MinIO under $MLFLOW_S3_BUCKET/$prefix"
  fi
}

check_edge_auth_gate() {
  local edge_required="$PHASE8_REQUIRE_AUTH_GATE"
  local edge_enabled="$MLFLOW_EDGE_ENABLED"
  local status_code
  local curl_resolve_args=()
  local curl_resolve curl_resolve_values

  if [[ "${CURL_RESOLVE:-}" != "" ]]; then
    IFS=',' read -r -a curl_resolve_values <<<"$CURL_RESOLVE"
    for curl_resolve in "${curl_resolve_values[@]}"; do
      curl_resolve="${curl_resolve//[[:space:]]/}"
      [[ -n "$curl_resolve" ]] || continue
      curl_resolve_args+=(--resolve "$curl_resolve")
    done
  elif [[ "${STAGING_IP:-}" != "" ]]; then
    curl_resolve_args+=(--resolve "${MLFLOW_DOMAIN}:443:${STAGING_IP}")
  fi

  if ! is_true "$edge_required"; then
    if is_true "$edge_enabled"; then
      warn "MLflow edge route marked enabled but PHASE8_REQUIRE_AUTH_GATE=$PHASE8_REQUIRE_AUTH_GATE"
    else
      ok "MLflow public edge route is intentionally not required in Phase 8 internal mode"
    fi
    return
  fi

  status_code="$(curl -ksS --noproxy "*" "${curl_resolve_args[@]}" -o /dev/null -w '%{http_code}' "$MLFLOW_URL" || true)"
  case "$status_code" in
    302|401|403)
      ok "MLflow unauthenticated edge request is gated with HTTP $status_code"
      ;;
    *)
      fail "MLflow unauthenticated edge request returned HTTP ${status_code:-000}; expected 302/401/403"
      ;;
  esac
}

MLFLOW_S3_ARTIFACT_PREFIX="$(normalize_prefix "$MLFLOW_S3_ARTIFACT_PREFIX")"
if [[ -z "$MLFLOW_S3_ARTIFACT_PREFIX" ]]; then
  fail "MLFLOW_S3_ARTIFACT_PREFIX must not be empty"
fi

check_non_placeholder MLFLOW_DB_NAME
check_non_placeholder MLFLOW_DB_USER
require_runtime_secret MLFLOW_DB_PASSWORD
require_runtime_secret MLFLOW_S3_ACCESS_KEY
require_runtime_secret MLFLOW_S3_SECRET_KEY
require_runtime_secret MINIO_ROOT_USER
require_runtime_secret MINIO_ROOT_PASSWORD

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

check_compose_config
check_container "$MLFLOW_CONTAINER"
check_no_host_ports "$MLFLOW_CONTAINER"
check_postgres_backend
check_internal_http
check_mlflow_smoke
check_minio_artifact_evidence
check_edge_auth_gate

if [[ "$status" -eq 0 ]]; then
  log "Phase 8 MLflow internal checks passed with $warnings warning(s)"
else
  log "Phase 8 MLflow internal checks failed with $warnings warning(s)"
fi

exit "$status"
