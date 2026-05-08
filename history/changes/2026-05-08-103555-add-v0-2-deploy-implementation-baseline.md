# Change - Add v0.2 deploy implementation baseline

Date: 2026-05-08 10:35 +0000
Agent: codex
Status: completed

## Why

v0.2 requires module implementation files for core, edge, Authentik, apps, backup, and v0.3 smoke prep.

## How

Added split env examples, Docker Compose modules, Nginx route skeletons, Authentik blueprints, MinIO policies, bootstrap/check/backup scripts, runbooks, and smoke report template without recording real secrets.

## Files

- deploy/

## Validation

- bash -n deploy/scripts/*.sh; docker compose config for all modules with env examples; nginx -t in nginx container with temporary self-signed cert; git diff --check

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M history/INDEX.md
?? deploy/
```
