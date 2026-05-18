# Change - Stabilize Phase 6 Overleaf staging runtime

Date: 2026-05-10 20:25 +0000
Agent: codex
Status: completed

## Why

Overleaf staging validation exposed runtime blockers: unavailable base image tag, shell env values with spaces, duplicate Nginx timeouts, TeX Live 2026/2025 mismatch, unavailable hcr-lvt package, and root-owned bind mount traversal blocking the www-data web process.

## How

Updated the image tag to 5.5.8, quoted env example values, removed duplicate Nginx timeouts, pinned tlmgr to the final TeX Live 2025 repository with self-update, removed hcr-lvt, and added Overleaf data ownership correction to 00-create-directories.sh.

## Files

- deploy/compose/overleaf/Dockerfile
- deploy/env/70-overleaf.env.example
- deploy/nginx/conf.d/70-overleaf.conf
- deploy/scripts/00-create-directories.sh
- deploy/reports/phase6-overleaf.md

## Validation

- STAGING_IP=127.0.0.1 PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false /opt/lab-stack/scripts/80-check-overleaf.sh

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/overleaf/Dockerfile
 M deploy/env/70-overleaf.env.example
 M deploy/nginx/conf.d/70-overleaf.conf
 M deploy/reports/phase6-overleaf.md
 M deploy/scripts/00-create-directories.sh
 M history/INDEX.md
 M history/daily/2026-05-10.md
?? history/sessions/2026-05-10-200900-codex-validate-phase-6-overleaf-staging-runtime.md
```
