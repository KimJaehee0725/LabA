# Change - Move LLM API watcher off port 3000

Date: 2026-05-12 05:55 +0000
Agent: codex
Status: completed

## Why

Phase 7 integrated 96-check-all.sh stopped at edge checks because an unrelated host process was listening on public port 3000.

## How

Changed the local LLM-API-Watcher .env PORT from 3000 to 3010, restarted it with run_server.sh, verified 3010 health, and reran integrated 96-check-all.sh with Phase 7 opt-in.

## Files

- deploy/reports/phase7-operational-baseline.md
- deploy/runbooks/full-pass-readiness.md

## Validation

- curl http://127.0.0.1:3010/health; STAGING_IP=127.0.0.1 ... LABSTACK_INCLUDE_OPS_BASELINE=true /opt/lab-stack/scripts/96-check-all.sh

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/env/90-backup.env.example
 M deploy/reports/phase6-overleaf.md
 M deploy/runbooks/README.md
 M deploy/runbooks/backup-restore.md
 M deploy/runbooks/full-pass-readiness.md
 M deploy/scripts/90-backup-all.sh
 M deploy/scripts/96-check-all.sh
 M deploy/scripts/97-disk-usage.sh
 M history/CONTEXT.md
 M history/INDEX.md
?? deploy/reports/phase7-operational-baseline.md
?? deploy/runbooks/phase7-operational-baseline.md
?? deploy/scripts/89-restore-rehearsal.sh
?? deploy/scripts/99-check-ops-baseline.sh
?? history/changes/2026-05-12-054624-implement-phase-7-internal-operational-baseline.md
?? history/daily/2026-05-12.md
?? history/experiments/0018-validate-phase-7-operational-baseline-runtime.md
```
