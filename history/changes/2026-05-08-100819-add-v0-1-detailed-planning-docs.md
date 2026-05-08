# Change - Add v0.1 detailed planning docs

Date: 2026-05-08 10:08 +0000
Agent: codex
Status: completed

## Why

The lab platform is complex enough that v0.2 implementation needs module-level plans before writing compose and ops files.

## How

Added docs/v0.1 with roadmap, core, edge, Authentik, Gitea, Plane, MLflow, Nextcloud/Collabora, Overleaf, backup/ops, implementation backlog, and v0.3 smoke plan. Added docs/README and linked v0 to v0.1.

## Files

- docs/README.md
- docs/v0/README.md
- docs/v0.1/README.md
- docs/v0.1/00-v0.2-v0.3-roadmap.md
- docs/v0.1/01-core-infrastructure.md
- docs/v0.1/02-edge-nginx-tls.md
- docs/v0.1/03-authentik-identity.md
- docs/v0.1/04-gitea-module.md
- docs/v0.1/05-plane-module.md
- docs/v0.1/06-mlflow-module.md
- docs/v0.1/07-nextcloud-collabora-module.md
- docs/v0.1/08-overleaf-module.md
- docs/v0.1/09-backup-restore-observability.md
- docs/v0.1/10-v0.2-implementation-backlog.md
- docs/v0.1/11-v0.3-smoke-test-plan.md

## Validation

- find docs -type f -name '*.md' -print0 | xargs -0 grep -n '[[:blank:]]$' || true

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
?? docs/
?? history/
?? init_docs/
```
