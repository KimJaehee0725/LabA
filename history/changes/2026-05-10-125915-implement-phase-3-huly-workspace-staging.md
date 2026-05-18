# Change - Implement Phase 3 Huly workspace staging

Date: 2026-05-10 12:59 +0000
Agent: codex
Status: conditional-pass

## Why

Phase 3 needed a concrete Huly workspace baseline that subagents can extend toward operational full pass.

## How

Added Huly compose, environment template, Nginx route, preflight/runtime/pilot checks, seed materials, runbook, docs, and deployed the core stack under /opt/lab-stack with optional GitHub and Calendar disabled until credentials exist.

## Files

- deploy/compose/huly/docker-compose.yml
- deploy/env/30-huly.env.example
- deploy/nginx/conf.d/20-huly.conf
- deploy/scripts/23-check-phase3-huly-preflight.sh
- deploy/scripts/30-check-huly.sh
- deploy/scripts/31-bootstrap-huly-workspace.sh
- deploy/scripts/32-check-huly-pilot.sh
- deploy/runbooks/phase3-huly.md
- deploy/huly/seed/workspace.seed.yaml
- deploy/reports/phase3-huly-pilot.md

## Validation

- bash -n deploy/scripts/00-create-directories.sh deploy/scripts/23-check-phase3-huly-preflight.sh deploy/scripts/30-check-huly.sh deploy/scripts/31-bootstrap-huly-workspace.sh deploy/scripts/32-check-huly-pilot.sh deploy/scripts/96-check-all.sh && git diff --check; compose config render from examples; PyYAML seed manifest parse; relaxed /opt/lab-stack/scripts/96-check-all.sh with LABSTACK_INCLUDE_HULY=true

## Risks / Follow-Ups

Full pass is still blocked by real DNS/TLS/SMTP, browser OIDC login, manual workspace seed/import confirmation, GitHub App credentials, Google Calendar credentials, and one-week pilot evidence.

## Git Status Snapshot

```text
M deploy/README.md
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
 M history/INDEX.md
?? deploy/compose/huly/
?? deploy/env/30-huly.env.example
?? deploy/huly/
?? deploy/nginx/conf.d/20-huly-forward-auth.conf.disabled
?? deploy/nginx/conf.d/20-huly.conf
?? deploy/reports/phase2-edge-auth-staging.md
?? deploy/reports/phase3-huly-pilot.md
?? deploy/runbooks/phase2-edge-auth.md
?? deploy/runbooks/phase3-huly.md
?? deploy/scripts/19-check-phase2-preflight.sh
?? deploy/scripts/22-bootstrap-authentik-oidc.sh
?? deploy/scripts/23-check-phase3-huly-preflight.sh
?? deploy/scripts/30-check-huly.sh
?? deploy/scripts/31-bootstrap-huly-workspace.sh
?? deploy/scripts/32-check-huly-pilot.sh
?? history/changes/2026-05-09-205004-implement-phase-2-edge-auth-staging-baseline.md
?? history/changes/2026-05-10-012047-operationalize-phase-2-full-pass-preflight-and-oidc-bootstrap.md
?? history/daily/2026-05-09.md
?? history/daily/2026-05-10.md
?? history/experiments/0002-run-phase-2-edge-auth-local-fallback-staging-gate.md
?? history/experiments/0003-phase-2-edge-auth-local-staging-validation.md
?? history/experiments/0004-run-phase-2-gate-on-opt-lab-stack.md
```
