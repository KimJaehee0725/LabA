# Change - Implement Phase 2 Edge/Auth staging baseline

Date: 2026-05-09 20:50 +0000
Agent: codex
Status: completed

## Why

Huly workspace MVP needs a staging-first Edge/Auth gate before Phase 3 Huly pilot.

## How

Aligned active compose and scripts to /opt/lab-stack and labstack networks, limited core to Postgres/Redis by default, updated Nginx/Auth staging config and Authentik app skeletons, added Phase 2 runbook/report, and refreshed Huly MVP docs.

## Files

- deploy/compose/core/docker-compose.yml
- deploy/compose/edge/docker-compose.yml
- deploy/compose/authentik/docker-compose.yml
- deploy/scripts/05-create-self-signed-cert.sh
- deploy/scripts/20-check-authentik.sh
- deploy/runbooks/phase2-edge-auth.md
- deploy/reports/phase2-edge-auth-staging.md

## Validation

- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for core/edge/authentik env examples; nginx:1.27-alpine nginx -t with temp staging cert; yaml parse blueprints; git diff --check; tracked secret scan

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/authentik/blueprints/30-applications.yaml
 M deploy/compose/authentik/docker-compose.yml
 M deploy/compose/core/docker-compose.yml
 M deploy/compose/edge/docker-compose.yml
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
?? history/daily/2026-05-09.md
```
