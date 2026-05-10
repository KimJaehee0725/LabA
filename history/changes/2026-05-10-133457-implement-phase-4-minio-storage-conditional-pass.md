# Change - Implement Phase 4 MinIO storage conditional pass

Date: 2026-05-10 13:34 +0000
Agent: codex
Status: completed

## Why

Phase 3 Huly full-pass is conditional until real DNS/TLS/SMTP/OAuth evidence is ready, so the next active surface is shared core MinIO storage.

## How

Added Phase 4 env, MinIO OIDC compose settings, Authentik policy claim mapping, files/s3 Nginx routing, bucket/policy/bootstrap checks, backup smoke, runbook/report, and validation matrix updates.

## Files

- deploy/env/35-minio-storage.env.example
- deploy/env/20-authentik.env.example
- deploy/compose/core/docker-compose.yml
- deploy/authentik/blueprints/20-oauth-scopes.yaml
- deploy/nginx/conf.d/30-minio-storage.conf
- deploy/scripts/00-create-directories.sh
- deploy/scripts/22-bootstrap-authentik-oidc.sh
- deploy/scripts/33-bootstrap-minio-storage.sh
- deploy/scripts/34-check-minio-storage.sh
- deploy/scripts/35-check-minio-backup-smoke.sh
- deploy/scripts/96-check-all.sh
- deploy/runbooks/phase4-minio-storage.md
- deploy/reports/phase4-minio-storage.md
- docs/huly-workspace-mvp/reference/validation.html

## Validation

- bash -n phase4 scripts; docker compose --profile minio config with example env; DRY_RUN=true 33-bootstrap; git diff --check

## Risks / Follow-Ups

- `/opt/lab-stack` staging execution is pending because the current shell user cannot read the root-owned runtime tree and passwordless sudo is unavailable.

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/authentik/blueprints/20-oauth-scopes.yaml
 M deploy/authentik/blueprints/30-applications.yaml
 M deploy/compose/authentik/docker-compose.yml
 M deploy/compose/core/docker-compose.yml
 M deploy/compose/edge/docker-compose.yml
 M deploy/env/20-authentik.env.example
 M deploy/env/README.md
 M deploy/nginx/conf.d/00-http-redirect.conf
 M deploy/nginx/conf.d/10-authentik.conf
 M deploy/nginx/nginx.conf
 M deploy/nginx/snippets/ssl-params.conf
 M deploy/runbooks/README.md
 M deploy/scripts/00-create-directories.sh
 M deploy/scripts/02-bootstrap-postgres.sh
 M deploy/scripts/04-check-core.sh
 M deploy/scripts/05-create-self-signed-cert.sh
 M deploy/scripts/10-check-edge.sh
 M deploy/scripts/20-check-authentik.sh
 M deploy/scripts/96-check-all.sh
 M deploy/scripts/lib/common.sh
 M docs/huly-workspace-mvp/layers/architecture.html
 M docs/huly-workspace-mvp/layers/roadmap.html
 M docs/huly-workspace-mvp/reference/backlog.html
 M docs/huly-workspace-mvp/reference/validation.html
 M docs/huly-workspace-mvp/workstreams/edge-auth.html
 M docs/huly-workspace-mvp/workstreams/huly.html
 M history/CONTEXT.md
 M history/INDEX.md
?? deploy/compose/huly/
?? deploy/env/30-huly.env.example
?? deploy/env/35-minio-storage.env.example
?? deploy/huly/
?? deploy/nginx/conf.d/20-huly-forward-auth.conf.disabled
?? deploy/nginx/conf.d/20-huly.conf
?? deploy/nginx/conf.d/30-minio-storage.conf
?? deploy/reports/phase2-edge-auth-staging.md
?? deploy/reports/phase3-huly-pilot.md
?? deploy/reports/phase4-minio-storage.md
?? deploy/runbooks/phase2-edge-auth.md
?? deploy/runbooks/phase3-huly.md
?? deploy/runbooks/phase4-minio-storage.md
?? deploy/scripts/19-check-phase2-preflight.sh
?? deploy/scripts/22-bootstrap-authentik-oidc.sh
?? deploy/scripts/23-check-phase3-huly-preflight.sh
?? deploy/scripts/30-check-huly.sh
?? deploy/scripts/31-bootstrap-huly-workspace.sh
?? deploy/scripts/32-check-huly-pilot.sh
?? deploy/scripts/33-bootstrap-minio-storage.sh
?? deploy/scripts/34-check-minio-storage.sh
?? deploy/scripts/35-check-minio-backup-smoke.sh
?? history/changes/2026-05-09-205004-implement-phase-2-edge-auth-staging-baseline.md
?? history/changes/2026-05-10-012047-operationalize-phase-2-full-pass-preflight-and-oidc-bootstrap.md
?? history/changes/2026-05-10-125915-implement-phase-3-huly-workspace-staging.md
?? history/daily/2026-05-09.md
?? history/daily/2026-05-10.md
?? history/experiments/0002-run-phase-2-edge-auth-local-fallback-staging-gate.md
?? history/experiments/0003-phase-2-edge-auth-local-staging-validation.md
?? history/experiments/0004-run-phase-2-gate-on-opt-lab-stack.md
?? history/experiments/0005-validate-phase-3-huly-staging-runtime.md
?? history/handoffs/2026-05-10-125929-phase-3-huly-full-pass-handoff.md
?? history/sessions/2026-05-10-132512-codex-implement-phase-4-minio-storage-conditional-pass.md
```
