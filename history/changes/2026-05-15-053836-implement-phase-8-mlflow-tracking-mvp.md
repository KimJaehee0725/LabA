# Change - Implement Phase 8 MLflow tracking MVP

Date: 2026-05-15 05:38 +0000
Agent: codex
Status: implemented

## Why

Phase 8 needs an active-stack MLflow service that uses shared Postgres and shared MinIO without exposing a public unauthenticated UI.

## How

Modernized MLflow compose/env, added bootstrap and runtime check scripts, wired MLflow into integrated checks, backup/restore rehearsal, ops baseline, runbooks, and reports. Public Nginx route is kept as a disabled Authentik-gated template.

## Files

- deploy/compose/mlflow/docker-compose.yml, deploy/scripts/60-check-mlflow.sh, deploy/scripts/61-bootstrap-mlflow.sh, deploy/scripts/90-backup-all.sh, deploy/scripts/89-restore-rehearsal.sh

## Validation

- git diff --check; bash -n deploy/scripts/*.sh deploy/scripts/lib/common.sh; docker compose config for MLflow; PHASE8_REQUIRE_AUTH_GATE=false /opt/lab-stack/scripts/60-check-mlflow.sh; relaxed 96-check-all with LABSTACK_INCLUDE_MLFLOW=true; LABSTACK_BACKUP_MLFLOW=true backup/restore rehearsal

## Risks / Follow-Ups

Strict public MLflow UI remains blocked until Authentik proxy/outpost evidence is configured; real DNS/TLS/SMTP and credential policy blockers remain outside Phase 8.

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/compose/mlflow/docker-compose.yml
 M deploy/data-model/lab-domain.v0.3.yaml
 M deploy/env/00-global.env.example
 M deploy/env/50-mlflow.env.example
 M deploy/env/80-minio-policies.env.example
 M deploy/env/90-backup.env.example
 M deploy/env/README.md
 M deploy/minio/policies/mlflow-artifacts-rw.json
 D deploy/nginx/conf.d/40-mlflow.conf
 M deploy/reports/phase7-operational-baseline.md
 M deploy/runbooks/README.md
 M deploy/runbooks/backup-restore.md
 M deploy/runbooks/full-pass-readiness.md
 M deploy/runbooks/mlflow.md
 M deploy/runbooks/phase7-operational-baseline.md
 M deploy/scripts/03-bootstrap-minio.sh
 M deploy/scripts/06-configure-hosts.sh
 M deploy/scripts/60-check-mlflow.sh
 M deploy/scripts/89-restore-rehearsal.sh
 M deploy/scripts/90-backup-all.sh
 M deploy/scripts/96-check-all.sh
 M deploy/scripts/99-check-ops-baseline.sh
 M history/INDEX.md
?? deploy/nginx/conf.d/40-mlflow.conf.disabled
?? deploy/reports/phase8-mlflow.md
?? deploy/scripts/61-bootstrap-mlflow.sh
?? history/daily/2026-05-15.md
```
