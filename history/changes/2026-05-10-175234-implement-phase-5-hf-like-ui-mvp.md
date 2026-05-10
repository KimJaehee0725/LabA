# Change - Implement Phase 5 HF-like UI MVP

Date: 2026-05-10 17:52 +0000
Agent: codex
Status: completed

## Why

Phase 4 MinIO conditional-pass 이후 실제 도메인 대기 시간을 활용해 모델/데이터셋 catalog UI를 먼저 staging에서 검증하기 위해 진행했다.

## How

FastAPI static/API app, HF UI compose stack, Nginx route, Authentik OIDC registration surface, MinIO service user/bootstrap, staging smoke check, runbook/report를 추가했다. Staging bypass는 45-hf-ui.env에서 명시적으로 켜는 경우에만 자동 검증에 사용된다.

## Files

- deploy/hf-ui/app/main.py
- deploy/hf-ui/app/static/app.js
- deploy/compose/hf-ui/docker-compose.yml
- deploy/env/45-hf-ui.env.example
- deploy/nginx/conf.d/45-hf-ui.conf
- deploy/scripts/43-bootstrap-hf-ui-storage.sh
- deploy/scripts/44-check-hf-ui.sh
- deploy/reports/phase5-hf-ui.md

## Validation

- bash -n deploy/scripts/00-create-directories.sh deploy/scripts/22-bootstrap-authentik-oidc.sh deploy/scripts/43-bootstrap-hf-ui-storage.sh deploy/scripts/44-check-hf-ui.sh deploy/scripts/96-check-all.sh
- python3 -m py_compile deploy/hf-ui/app/main.py
- docker compose -f deploy/compose/hf-ui/docker-compose.yml config
- STAGING_IP=127.0.0.1 PHASE5_REQUIRE_REAL_DOMAINS=false /opt/lab-stack/scripts/44-check-hf-ui.sh
- STAGING_IP=127.0.0.1 ... LABSTACK_INCLUDE_HF_UI=true /opt/lab-stack/scripts/96-check-all.sh

## Risks / Follow-Ups

-

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
?? deploy/compose/hf-ui/
?? deploy/compose/huly/
?? deploy/env/30-huly.env.example
?? deploy/env/35-minio-storage.env.example
?? deploy/env/45-hf-ui.env.example
?? deploy/hf-ui/
?? deploy/huly/
?? deploy/nginx/conf.d/20-huly-forward-auth.conf.disabled
?? deploy/nginx/conf.d/20-huly.conf
?? deploy/nginx/conf.d/30-minio-storage.conf
?? deploy/nginx/conf.d/45-hf-ui.conf
?? deploy/reports/phase2-edge-auth-staging.md
?? deploy/reports/phase3-huly-pilot.md
?? deploy/reports/phase4-minio-storage.md
?? deploy/reports/phase5-hf-ui.md
?? deploy/runbooks/phase2-edge-auth.md
?? deploy/runbooks/phase3-huly.md
?? deploy/runbooks/phase4-minio-storage.md
?? deploy/runbooks/phase5-hf-ui.md
?? deploy/scripts/19-check-phase2-preflight.sh
?? deploy/scripts/22-bootstrap-authentik-oidc.sh
?? deploy/scripts/23-check-phase3-huly-preflight.sh
?? deploy/scripts/30-check-huly.sh
?? deploy/scripts/31-bootstrap-huly-workspace.sh
?? deploy/scripts/32-check-huly-pilot.sh
?? deploy/scripts/33-bootstrap-minio-storage.sh
?? deploy/scripts/34-check-minio-storage.sh
?? deploy/scripts/35-check-minio-backup-smoke.sh
?? deploy/scripts/43-bootstrap-hf-ui-storage.sh
?? deploy/scripts/44-check-hf-ui.sh
?? history/changes/2026-05-09-205004-implement-phase-2-edge-auth-staging-baseline.md
?? history/changes/2026-05-10-012047-operationalize-phase-2-full-pass-preflight-and-oidc-bootstrap.md
?? history/changes/2026-05-10-125915-implement-phase-3-huly-workspace-staging.md
?? history/changes/2026-05-10-133457-implement-phase-4-minio-storage-conditional-pass.md
?? history/changes/2026-05-10-140100-stabilize-phase-4-minio-staging-runtime.md
?? history/daily/2026-05-09.md
?? history/daily/2026-05-10.md
?? history/experiments/0002-run-phase-2-edge-auth-local-fallback-staging-gate.md
?? history/experiments/0003-phase-2-edge-auth-local-staging-validation.md
?? history/experiments/0004-run-phase-2-gate-on-opt-lab-stack.md
?? history/experiments/0005-validate-phase-3-huly-staging-runtime.md
?? history/experiments/0006-validate-phase-4-minio-storage-static-surface.md
?? history/experiments/0007-validate-phase-4-minio-staging-runtime.md
?? history/handoffs/2026-05-10-125929-phase-3-huly-full-pass-handoff.md
?? history/handoffs/2026-05-10-133546-continue-phase-4-minio-staging-on-opt-lab-stack.md
?? history/sessions/2026-05-10-132512-codex-implement-phase-4-minio-storage-conditional-pass.md
?? history/sessions/2026-05-10-173823-codex-implement-phase-5-hf-like-ui-mvp.md
```
