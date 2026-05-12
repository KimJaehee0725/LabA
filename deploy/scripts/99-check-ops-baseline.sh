#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

BACKUP_RUN_ROOT=""
while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --backup-root)
      shift
      BACKUP_RUN_ROOT="${1:-}"
      [[ -n "$BACKUP_RUN_ROOT" ]] || die "--backup-root requires a value"
      ;;
    -h|--help)
      cat <<USAGE
Usage: ${0##*/} [--dry-run] [--backup-root PATH]
USAGE
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

INCOMING_PHASE7_REQUIRE_BACKUP_EVIDENCE="${PHASE7_REQUIRE_BACKUP_EVIDENCE:-}"
INCOMING_PHASE7_REQUIRE_RESTORE_REHEARSAL="${PHASE7_REQUIRE_RESTORE_REHEARSAL:-}"
INCOMING_LABSTACK_INCLUDE_HULY="${LABSTACK_INCLUDE_HULY:-}"
INCOMING_LABSTACK_INCLUDE_MINIO="${LABSTACK_INCLUDE_MINIO:-}"
INCOMING_LABSTACK_INCLUDE_HF_UI="${LABSTACK_INCLUDE_HF_UI:-}"
INCOMING_LABSTACK_INCLUDE_OVERLEAF="${LABSTACK_INCLUDE_OVERLEAF:-}"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/30-huly.env" \
  "$ENV_DIR/35-minio-storage.env" \
  "$ENV_DIR/45-hf-ui.env" \
  "$ENV_DIR/70-overleaf.env" \
  "$ENV_DIR/90-backup.env"

LAB_BACKUP_ROOT="${LAB_BACKUP_ROOT:-/mnt/backup/lab}"
LAB_MINIO_DATA_ROOT="${LAB_MINIO_DATA_ROOT:-/mnt/hdd/minio}"
BACKUP_ARCHIVE_ROOT="${BACKUP_ROOT:-${LAB_BACKUP_ROOT}/archive}"
PHASE7_REQUIRE_BACKUP_EVIDENCE="${PHASE7_REQUIRE_BACKUP_EVIDENCE:-true}"
PHASE7_REQUIRE_RESTORE_REHEARSAL="${PHASE7_REQUIRE_RESTORE_REHEARSAL:-true}"
PHASE7_DISK_WARN_PERCENT="${PHASE7_DISK_WARN_PERCENT:-85}"
PHASE7_DISK_FAIL_PERCENT="${PHASE7_DISK_FAIL_PERCENT:-95}"
PHASE7_CERT_WARN_DAYS="${PHASE7_CERT_WARN_DAYS:-30}"
PHASE7_CERT_FAIL_DAYS="${PHASE7_CERT_FAIL_DAYS:-7}"
LABSTACK_INCLUDE_HULY="${LABSTACK_INCLUDE_HULY:-true}"
LABSTACK_INCLUDE_MINIO="${LABSTACK_INCLUDE_MINIO:-true}"
LABSTACK_INCLUDE_HF_UI="${LABSTACK_INCLUDE_HF_UI:-true}"
LABSTACK_INCLUDE_OVERLEAF="${LABSTACK_INCLUDE_OVERLEAF:-true}"

[[ -n "$INCOMING_PHASE7_REQUIRE_BACKUP_EVIDENCE" ]] && PHASE7_REQUIRE_BACKUP_EVIDENCE="$INCOMING_PHASE7_REQUIRE_BACKUP_EVIDENCE"
[[ -n "$INCOMING_PHASE7_REQUIRE_RESTORE_REHEARSAL" ]] && PHASE7_REQUIRE_RESTORE_REHEARSAL="$INCOMING_PHASE7_REQUIRE_RESTORE_REHEARSAL"
[[ -n "$INCOMING_LABSTACK_INCLUDE_HULY" ]] && LABSTACK_INCLUDE_HULY="$INCOMING_LABSTACK_INCLUDE_HULY"
[[ -n "$INCOMING_LABSTACK_INCLUDE_MINIO" ]] && LABSTACK_INCLUDE_MINIO="$INCOMING_LABSTACK_INCLUDE_MINIO"
[[ -n "$INCOMING_LABSTACK_INCLUDE_HF_UI" ]] && LABSTACK_INCLUDE_HF_UI="$INCOMING_LABSTACK_INCLUDE_HF_UI"
[[ -n "$INCOMING_LABSTACK_INCLUDE_OVERLEAF" ]] && LABSTACK_INCLUDE_OVERLEAF="$INCOMING_LABSTACK_INCLUDE_OVERLEAF"

status=0
warnings=0

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

is_example_value() {
  local value="${1:-}"
  [[ "$value" == *example.edu* || "$value" == *example.ac.kr* ]]
}

find_latest_backup_root() {
  find "$BACKUP_ARCHIVE_ROOT/phase7" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort | tail -n 1
}

check_container() {
  local name="$1"
  local state health
  if is_dry_run; then
    printf '+ docker inspect %q\n' "$name"
    return 0
  fi
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
  if is_dry_run; then
    printf '+ check no host ports for %q\n' "$name"
    return 0
  fi
  ports="$(docker inspect -f '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' "$name" 2>/dev/null || true)"
  if [[ -n "$ports" ]]; then
    fail "$name publishes host ports: $ports"
  else
    ok "$name publishes no host ports"
  fi
}

check_nginx_ports() {
  local published
  local port
  local unexpected=false
  if is_dry_run; then
    printf '+ check nginx publishes only 80/443\n'
    return 0
  fi
  check_container nginx
  published="$(docker inspect -f '{{range $port, $bindings := .NetworkSettings.Ports}}{{if $bindings}}{{$port}} {{end}}{{end}}' nginx 2>/dev/null || true)"
  if [[ "$published" == *"80/tcp"* && "$published" == *"443/tcp"* ]]; then
    ok "nginx publishes HTTP/HTTPS ports"
  else
    fail "nginx does not publish both 80/tcp and 443/tcp"
  fi
  for port in $published; do
    case "$port" in
      80/tcp|443/tcp) ;;
      *) unexpected=true ;;
    esac
  done
  if [[ "$unexpected" == "false" ]]; then
    ok "nginx published ports are limited to HTTP/HTTPS"
  else
    warn "nginx published ports should be reviewed: ${published:-none}"
  fi
}

check_active_containers() {
  local containers=(
    postgres
    redis
    authentik-server
    authentik-worker
  )
  if is_true "$LABSTACK_INCLUDE_HULY"; then
    containers+=(
      huly-cockroach
      huly-redpanda
      huly-minio
      huly-elastic
      huly-rekoni
      huly-transactor
      huly-collaborator
      huly-account
      huly-workspace
      huly-front
      huly-fulltext
      huly-stats
      huly-kvs
    )
  fi
  if is_true "$LABSTACK_INCLUDE_MINIO"; then
    containers+=(minio)
  fi
  if is_true "$LABSTACK_INCLUDE_HF_UI"; then
    containers+=(hf-ui)
  fi
  if is_true "$LABSTACK_INCLUDE_OVERLEAF"; then
    containers+=(overleaf overleaf-mongo overleaf-redis)
  fi
  for container in "${containers[@]}"; do
    check_container "$container"
    check_no_host_ports "$container"
  done
  check_nginx_ports
}

check_paths_and_permissions() {
  local path
  if is_dry_run; then
    printf '+ check directories, env modes, and TLS private key mode\n'
    return 0
  fi
  for path in "$LAB_STACK_ROOT" "$ENV_DIR" "$LAB_BACKUP_ROOT"; do
    if [[ -d "$path" ]]; then
      ok "directory exists: $path"
    else
      fail "missing directory: $path"
    fi
  done

  if [[ -f "$LAB_STACK_ROOT/certs/private/staging.key" ]]; then
    local key_mode
    key_mode="$(stat -c '%a' "$LAB_STACK_ROOT/certs/private/staging.key" 2>/dev/null || true)"
    if [[ "$key_mode" =~ ^[0-7]+$ && $((10#$key_mode)) -le 600 ]]; then
      ok "TLS private key mode is $key_mode"
    else
      fail "TLS private key mode must be 0600 or stricter; observed ${key_mode:-missing}"
    fi
  else
    fail "missing TLS private key path for metadata check"
  fi

  while IFS= read -r env_file; do
    local mode
    mode="$(stat -c '%a' "$env_file" 2>/dev/null || true)"
    if [[ "$mode" =~ ^[0-7]+$ && $((10#$mode)) -le 640 ]]; then
      ok "env file mode is restricted: $env_file"
    else
      fail "env file mode must be 0640 or stricter: $env_file observed ${mode:-missing}"
    fi
  done < <(find "$ENV_DIR" -maxdepth 1 -type f -name '*.env' 2>/dev/null | sort)
}

check_disk_usage() {
  local path pct
  if is_dry_run; then
    printf '+ check disk usage for %q %q %q\n' "$LAB_STACK_ROOT" "$LAB_BACKUP_ROOT" "$LAB_MINIO_DATA_ROOT"
    return 0
  fi
  for path in "$LAB_STACK_ROOT" "$LAB_BACKUP_ROOT" "$LAB_MINIO_DATA_ROOT"; do
    [[ -e "$path" ]] || { warn "disk path missing, skipped: $path"; continue; }
    pct="$(df -P "$path" | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')"
    if [[ -z "$pct" ]]; then
      warn "could not read disk usage for $path"
    elif ((pct >= PHASE7_DISK_FAIL_PERCENT)); then
      fail "disk usage is ${pct}% for $path"
    elif ((pct >= PHASE7_DISK_WARN_PERCENT)); then
      warn "disk usage is ${pct}% for $path"
    else
      ok "disk usage is ${pct}% for $path"
    fi
  done
}

check_cert_expiry() {
  local cert="$LAB_STACK_ROOT/certs/staging.crt"
  local end_epoch now_epoch days_left
  if is_dry_run; then
    printf '+ check certificate expiry for %q\n' "$cert"
    return 0
  fi
  if [[ ! -f "$cert" ]]; then
    fail "missing certificate: $cert"
    return
  fi
  end_epoch="$(date -u -d "$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)" +%s 2>/dev/null || true)"
  now_epoch="$(date -u +%s)"
  if [[ -z "$end_epoch" ]]; then
    fail "could not parse certificate expiry: $cert"
    return
  fi
  days_left=$(((end_epoch - now_epoch) / 86400))
  if ((days_left < PHASE7_CERT_FAIL_DAYS)); then
    fail "certificate expires in ${days_left} days"
  elif ((days_left < PHASE7_CERT_WARN_DAYS)); then
    warn "certificate expires in ${days_left} days"
  else
    ok "certificate expires in ${days_left} days"
  fi
}

check_backup_and_restore_evidence() {
  if is_dry_run; then
    printf '+ check backup manifest and restore rehearsal evidence\n'
    return 0
  fi
  if [[ -z "$BACKUP_RUN_ROOT" ]]; then
    BACKUP_RUN_ROOT="$(find_latest_backup_root || true)"
  fi
  if ! is_true "$PHASE7_REQUIRE_BACKUP_EVIDENCE"; then
    warn "backup evidence requirement skipped: PHASE7_REQUIRE_BACKUP_EVIDENCE=$PHASE7_REQUIRE_BACKUP_EVIDENCE"
    return
  fi
  [[ -n "$BACKUP_RUN_ROOT" ]] || { fail "no Phase 7 backup root found"; return; }
  [[ -f "$BACKUP_RUN_ROOT/manifest.tsv" ]] || { fail "missing backup manifest: $BACKUP_RUN_ROOT/manifest.tsv"; return; }
  ok "backup manifest exists: $BACKUP_RUN_ROOT/manifest.tsv"
  if awk -F '\t' 'BEGIN {ok=0} $1=="phase7" && $2=="manifest" {ok=1} END {exit ok ? 0 : 1}' "$BACKUP_RUN_ROOT/manifest.tsv"; then
    ok "backup manifest self-entry exists"
  else
    fail "backup manifest is missing self-entry"
  fi
  if ! is_true "$PHASE7_REQUIRE_RESTORE_REHEARSAL"; then
    warn "restore rehearsal requirement skipped: PHASE7_REQUIRE_RESTORE_REHEARSAL=$PHASE7_REQUIRE_RESTORE_REHEARSAL"
    return
  fi
  [[ -f "$BACKUP_RUN_ROOT/restore-rehearsal.tsv" ]] || { fail "missing restore rehearsal report: $BACKUP_RUN_ROOT/restore-rehearsal.tsv"; return; }
  if awk -F '\t' '$2=="fail" {exit 1} END {exit 0}' "$BACKUP_RUN_ROOT/restore-rehearsal.tsv"; then
    ok "restore rehearsal report has no failing checks"
  else
    fail "restore rehearsal report contains failing checks"
  fi
}

check_secret_hygiene() {
  local high_risk_count soft_count
  local secret_hits_file
  require_cmd rg
  if is_dry_run; then
    printf '+ rg high-risk secret patterns without printing values\n'
    return 0
  fi
  secret_hits_file="$(mktemp /tmp/lab-stack-phase7-secret-hits.XXXXXX)"
  high_risk_count="$(
    {
      rg -n --hidden --glob '!.git' --glob '!history/archive/**' \
        'ghp_[[:alnum:]_]+|github_pat_[[:alnum:]_]+|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}' \
        "$PWD" 2>/dev/null || true
    } | awk -F ':' '{print $1 ":" $2}' | sort -u | tee "$secret_hits_file" | wc -l
  )"
  if [[ "$high_risk_count" == "0" ]]; then
    ok "no high-risk repo-facing secret patterns found"
  else
    fail "high-risk repo-facing secret pattern hits found; inspect $secret_hits_file"
  fi

  soft_count="$(
    {
      rg -n --hidden --glob '!.git' --glob '!history/archive/**' \
        'AUTHENTIK_.*(PASSWORD|TOKEN|SECRET)|OIDC_CLIENT_SECRET|SMTP|PRIVATE_KEY|SESSION_SECRET|ACCESS_KEY|SECRET_KEY' \
        deploy docs history 2>/dev/null || true
    } | awk -F ':' '{print $1 ":" $2}' | sort -u | wc -l
  )"
  if [[ "$soft_count" == "0" ]]; then
    ok "no secret-variable references found in tracked docs"
  else
    warn "secret-variable references found in tracked docs/scripts: $soft_count line refs; classify placeholders before strict full-pass"
  fi
}

check_strict_blockers_are_visible() {
  local blocker_count=0
  for name in ROOT_DOMAIN AUTH_DOMAIN HULY_DOMAIN FILES_DOMAIN S3_DOMAIN HF_DOMAIN OVERLEAF_DOMAIN; do
    if is_example_value "${!name:-}"; then
      warn "$name still uses example-domain value; strict full-pass remains blocked"
      blocker_count=$((blocker_count + 1))
    fi
  done
  for name in AUTHENTIK_EMAIL__HOST AUTHENTIK_EMAIL__USERNAME AUTHENTIK_EMAIL__PASSWORD AUTHENTIK_EMAIL__FROM; do
    if is_placeholder "${!name:-}" || is_example_value "${!name:-}"; then
      warn "$name is placeholder/example; strict SMTP full-pass remains blocked"
      blocker_count=$((blocker_count + 1))
    fi
  done
  if ((blocker_count == 0)); then
    ok "strict DNS/SMTP env blockers are not obvious from env values"
  else
    warn "strict external blockers recorded as warnings: $blocker_count"
  fi
}

if is_dry_run; then
  log "dry-run Phase 7 ops baseline check"
fi

check_active_containers
check_paths_and_permissions
check_disk_usage
check_cert_expiry
check_backup_and_restore_evidence
check_secret_hygiene
check_strict_blockers_are_visible

if [[ "$status" -eq 0 ]]; then
  log "Phase 7 internal ops baseline passed with $warnings warning(s)"
else
  log "Phase 7 internal ops baseline failed with $warnings warning(s)"
fi

exit "$status"
