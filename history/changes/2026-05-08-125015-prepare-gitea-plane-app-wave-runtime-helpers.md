# Change - Prepare Gitea Plane app wave runtime helpers

Date: 2026-05-08 12:50 +0000
Agent: codex
Status: completed

## Why

After Runtime Gate 1 passed, Gitea and Plane need app-wave bootstrap/check helpers that preserve secret hygiene and support 2222 only when Gitea is in scope.

## How

Updated Postgres bootstrap to sync configured app role passwords, added MinIO service user helper with redacted dry-run output, made edge port check conditionally allow Gitea SSH, aligned Gitea/Plane checks with split env files and MinIO bucket checks, and documented the app-wave sequence.

## Files

- deploy/scripts/02-bootstrap-postgres.sh
- deploy/scripts/08-create-minio-service-users.sh
- deploy/scripts/10-check-edge.sh
- deploy/scripts/41-check-gitea.sh
- deploy/scripts/51-check-plane.sh
- deploy/runbooks/gitea.md
- deploy/runbooks/plane.md

## Validation

- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for gitea and plane; dry-run MinIO bootstrap/service user helpers; deploy/scripts/10-check-edge.sh with and without ALLOW_GITEA_SSH=true; git diff --check

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/env/30-gitea.env.example
 M deploy/env/40-plane.env.example
 M deploy/env/README.md
 M deploy/runbooks/README.md
 M deploy/runbooks/gitea.md
 M deploy/runbooks/plane.md
 M deploy/scripts/02-bootstrap-postgres.sh
 M deploy/scripts/03-bootstrap-minio.sh
 M deploy/scripts/10-check-edge.sh
 M deploy/scripts/41-check-gitea.sh
 M deploy/scripts/51-check-plane.sh
 M history/INDEX.md
?? deploy/scripts/08-create-minio-service-users.sh
```
