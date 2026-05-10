#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/30-huly.env"

DEPLOY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SEED_ROOT="${HULY_SEED_ROOT:-${LAB_STACK_ROOT}/huly/seed}"
if [[ ! -d "$SEED_ROOT" && -d "$DEPLOY_ROOT/huly/seed" ]]; then
  SEED_ROOT="$DEPLOY_ROOT/huly/seed"
fi

required_files=(
  README.md
  workspace.seed.yaml
  docs/lab-handbook.md
  docs/meeting-notes.md
  issues/experiment-task.md
  issues/paper-milestone.md
  issues/github-sync-issue.md
  checklists/onboarding-checklist.md
)

missing=0
for file in "${required_files[@]}"; do
  if [[ -f "$SEED_ROOT/$file" ]]; then
    log "ok: seed artifact exists: $SEED_ROOT/$file"
  else
    log "fail: missing seed artifact: $SEED_ROOT/$file"
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  die "Huly seed bundle is incomplete"
fi

cat <<CHECKLIST
Huly workspace seed bundle is ready at:
  $SEED_ROOT

Manual seed steps for Phase 3:
1. Create or enter the pilot workspace at https://${HULY_DOMAIN:-huly.lab.example.ac.kr}.
2. Create channels: #general, #research, #paper, #infra, #random.
3. Create projects: Experiments, Papers, Infrastructure, Datasets, Onboarding.
4. Copy docs/lab-handbook.md and docs/meeting-notes.md into Huly documents/wiki.
5. Create issues from issues/*.md and set assignee, due date, status, and project.
6. Use checklists/onboarding-checklist.md for pilot user onboarding.
7. Record completion evidence in deploy/reports/phase3-huly-pilot.md.

No stable Huly self-host API/CLI was available in the inspected upstream, so this script validates and prints the deterministic manual seed procedure instead of writing to Huly data stores.
CHECKLIST
