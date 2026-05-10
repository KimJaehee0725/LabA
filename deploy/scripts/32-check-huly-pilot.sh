#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/30-huly.env"

DEPLOY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT_FILE="${HULY_PHASE3_REPORT:-${LAB_STACK_ROOT}/reports/phase3-huly-pilot.md}"
if [[ ! -f "$REPORT_FILE" && -f "$DEPLOY_ROOT/reports/phase3-huly-pilot.md" ]]; then
  REPORT_FILE="$DEPLOY_ROOT/reports/phase3-huly-pilot.md"
fi

SEED_ROOT="${HULY_SEED_ROOT:-${LAB_STACK_ROOT}/huly/seed}"
if [[ ! -d "$SEED_ROOT" && -d "$DEPLOY_ROOT/huly/seed" ]]; then
  SEED_ROOT="$DEPLOY_ROOT/huly/seed"
fi

PHASE3_REQUIRE_PILOT_FULL_PASS="${PHASE3_REQUIRE_PILOT_FULL_PASS:-true}"
status=0

fail() {
  log "fail: $*"
  status=1
}

ok() {
  log "ok: $*"
}

if [[ -f "$SEED_ROOT/workspace.seed.yaml" ]]; then
  ok "seed manifest exists"
else
  fail "missing seed manifest: $SEED_ROOT/workspace.seed.yaml"
fi

if [[ -f "$REPORT_FILE" ]]; then
  ok "phase3 report exists: $REPORT_FILE"
else
  fail "missing phase3 report: $REPORT_FILE"
fi

if [[ -f "$REPORT_FILE" ]]; then
  if grep -Eq '^Result: pass$' "$REPORT_FILE"; then
    ok "phase3 report is full pass"
  elif [[ "$PHASE3_REQUIRE_PILOT_FULL_PASS" == "true" || "$PHASE3_REQUIRE_PILOT_FULL_PASS" == "1" ]]; then
    fail "phase3 report is not full pass"
  else
    log "phase3 report is not full pass; accepted because PHASE3_REQUIRE_PILOT_FULL_PASS=$PHASE3_REQUIRE_PILOT_FULL_PASS"
  fi

  for marker in "OIDC login" "Workspace seed" "GitHub sync" "Google Calendar" "Notion sample" "Pilot usage"; do
    if grep -qi "$marker" "$REPORT_FILE"; then
      ok "report contains marker: $marker"
    else
      fail "report missing marker: $marker"
    fi
  done
fi

if [[ "$status" -eq 0 ]]; then
  log "Huly pilot report checks passed"
else
  log "Huly pilot report checks failed"
fi

exit "$status"
