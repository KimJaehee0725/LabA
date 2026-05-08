# Change - Validate v0.2.1 staging current wave

Date: 2026-05-08 14:34 +0000
Agent: codex
Status: completed

## Why

Current core edge Authentik Gitea Plane wave needed practical staging smoke before tagging and moving v0.3 Plane SSO work to blocker status.

## How

Ran static/runtime/security checks, fixed Plane auth and upload routing, added Plane instance bootstrap, added Gitea bootstrap admin contract, validated Authentik/Gitea/Plane smoke flows, restart persistence, and cleanup.

## Files

- deploy/reports/v0.2.1-staging-validation.md
- deploy/nginx/conf.d/20-plane.conf
- deploy/scripts/40-bootstrap-gitea.sh
- deploy/scripts/50-bootstrap-plane.sh

## Validation

- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for core/edge/authentik/gitea/plane; 04/10/20/41/50/51 runtime checks; Gitea OIDC SSH LFS smoke; Plane workspace issue attachment smoke; controlled restart persistence

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/plane/docker-compose.yml
 M deploy/env/30-gitea.env.example
 M deploy/env/40-plane.env.example
 M deploy/nginx/conf.d/20-plane.conf
 M deploy/scripts/40-bootstrap-gitea.sh
 M deploy/scripts/41-check-gitea.sh
 M deploy/scripts/50-bootstrap-plane.sh
 M deploy/scripts/51-check-plane.sh
 M history/INDEX.md
?? deploy/reports/v0.2.1-staging-validation.md
```
