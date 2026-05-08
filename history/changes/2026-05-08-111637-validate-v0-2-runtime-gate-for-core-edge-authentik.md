# Change - Validate v0.2 runtime gate for core edge authentik

Date: 2026-05-08 11:16 +0000
Agent: codex
Status: completed

## Why

Runtime Gate 1 needed real core -> edge -> Authentik startup validation before app-wave services.

## How

Added staging host and self-signed cert helpers, fixed Authentik blueprint mounts and writable directories, fixed MinIO mc alias handling, forwarded Authorization through Nginx, tightened edge port checks, and made the Authentik gate verify required groups from inside the worker container.

## Files

- deploy/scripts/03-bootstrap-minio.sh
- deploy/scripts/20-check-authentik.sh
- deploy/nginx/snippets/proxy-params.conf
- deploy/compose/authentik/docker-compose.yml
- deploy/runbooks/v0.2-runtime-gate-1.md

## Validation

- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for core/edge/authentik; nginx -t in nginx container with generated self-signed cert; contained runtime smoke for core, edge, authentik passed

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/compose/authentik/docker-compose.yml
 M deploy/env/20-authentik.env.example
 M deploy/nginx/snippets/proxy-params.conf
 M deploy/runbooks/README.md
 M deploy/runbooks/authentik.md
 M deploy/runbooks/edge-nginx.md
 M deploy/scripts/00-create-directories.sh
 M deploy/scripts/03-bootstrap-minio.sh
 M deploy/scripts/10-check-edge.sh
 M deploy/scripts/20-check-authentik.sh
 M history/INDEX.md
?? deploy/runbooks/v0.2-runtime-gate-1.md
?? deploy/scripts/05-create-self-signed-cert.sh
?? deploy/scripts/06-configure-hosts.sh
```
