# Change - Validate Gitea Plane app wave runtime

Date: 2026-05-08 13:30 +0000
Agent: codex
Status: completed

## Why

Gitea and Plane app wave needed real staging runtime fixes after core edge authentik gate passed.

## How

Created Authentik OIDC providers without printing secrets, updated root-only env files via Docker root mount, fixed MinIO mc entrypoint usage, made Gitea install/SSH/LFS/CA settings match runtime, and aligned Plane v0.25 commands, migrator, and Redis Celery broker env.

## Files

- deploy/compose/gitea/docker-compose.yml
- deploy/compose/plane/docker-compose.yml
- deploy/gitea/app.ini.template
- deploy/scripts/00-create-directories.sh
- deploy/scripts/03-bootstrap-minio.sh
- deploy/scripts/08-create-minio-service-users.sh
- deploy/scripts/41-check-gitea.sh
- deploy/scripts/51-check-plane.sh

## Validation

- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for gitea and plane with real env temp copies; curl Authentik discovery for gitea/plane; curl Gitea API; curl Plane web; Gitea doctor check; MinIO bucket ls for gitea-lfs and plane-uploads; Docker socket mount rg check; git diff --check

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/gitea/docker-compose.yml
 M deploy/compose/plane/docker-compose.yml
 M deploy/gitea/app.ini.template
 M deploy/scripts/00-create-directories.sh
 M deploy/scripts/03-bootstrap-minio.sh
 M deploy/scripts/08-create-minio-service-users.sh
 M deploy/scripts/41-check-gitea.sh
 M deploy/scripts/51-check-plane.sh
 M history/INDEX.md
```
