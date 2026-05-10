# Change - Operationalize Phase 2 full-pass preflight and OIDC bootstrap

Date: 2026-05-10 01:20 +0000
Agent: codex
Status: conditional-pass

## Why

운영 기준 full-pass 계획에서 /opt/lab-stack preflight와 Huly/MinIO/HF UI OIDC provider 생성/검증이 자동화되지 않아 실행자가 수동 판단해야 했다.

## How

19-check-phase2-preflight.sh로 운영 root, env, TLS key, Authentik data ownership, SMTP/OIDC env를 검증하고 22-bootstrap-authentik-oidc.sh로 세 OIDC provider/application을 idempotent하게 만든다. Runbook과 report에 full-pass 명령과 fallback 검증 결과를 반영했다.

## Files

- deploy/scripts/19-check-phase2-preflight.sh
- deploy/scripts/22-bootstrap-authentik-oidc.sh
- deploy/runbooks/phase2-edge-auth.md
- deploy/reports/phase2-edge-auth-staging.md

## Validation

- bash -n deploy/scripts/19-check-phase2-preflight.sh deploy/scripts/22-bootstrap-authentik-oidc.sh deploy/scripts/20-check-authentik.sh deploy/scripts/96-check-all.sh deploy/scripts/lib/common.sh
- git diff --check
- PHASE2_REQUIRE_SMTP=false STAGING_IP=127.0.0.1 LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env deploy/scripts/96-check-all.sh

## Risks / Follow-Ups

실제 full-pass는 여전히 sudo 가능한 /opt/lab-stack, 학교 DNS/TLS/SMTP, admin 2FA와 invitation 수동 검증이 있어야 한다. 현재 운영 preflight는 /opt/lab-stack 부재로 실패한다.

## Git Status Snapshot

```text
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
 M docs/huly-workspace-mvp/layers/roadmap.html
 M docs/huly-workspace-mvp/reference/backlog.html
 M docs/huly-workspace-mvp/workstreams/edge-auth.html
 M history/INDEX.md
?? deploy/reports/phase2-edge-auth-staging.md
?? deploy/runbooks/phase2-edge-auth.md
?? deploy/scripts/19-check-phase2-preflight.sh
?? deploy/scripts/22-bootstrap-authentik-oidc.sh
?? history/changes/2026-05-09-205004-implement-phase-2-edge-auth-staging-baseline.md
?? history/daily/2026-05-09.md
?? history/daily/2026-05-10.md
?? history/experiments/0002-run-phase-2-edge-auth-local-fallback-staging-gate.md
?? history/experiments/0003-phase-2-edge-auth-local-staging-validation.md
```
