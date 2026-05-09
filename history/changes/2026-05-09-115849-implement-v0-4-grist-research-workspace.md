# Change - Implement v0.4 Grist research workspace

Date: 2026-05-09 11:58 +0000
Agent: codex
Status: done

## Why

v0.4 requires a strict-OSS Notion-like research workspace layer while preserving the validated v0.3 MLflow and Nextcloud/Collabora baseline.

## How

Added Grist env/compose/Nginx/Auth bootstrap, v0.4 domain catalog, Grist research hub seed/check scripts, Plane/Nextcloud v0.4 seed support, backup/integrated-check wiring, and runbook/docs/report updates. Corrected Grist Docker image tag to gristlabs/grist-oss:1.7.13 while documenting release label v1.7.13.

## Files

- deploy/compose/grist/docker-compose.yml
- deploy/env/65-grist.env.example
- deploy/scripts/75-seed-grist-research-hub.sh
- deploy/scripts/76-check-grist.sh
- deploy/data-model/lab-domain.v0.4.yaml

## Validation

- git diff --check; bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; YAML parse for v0.3/v0.4 catalog, Authentik blueprint, Grist compose; docker compose config for Grist; disposable Grist v1.7.13 API seed/idempotency smoke; backup dry-run with grist database/persist entries.

## Risks / Follow-Ups

Full OIDC redirect, external Nginx route, and integrated 96-check-all still need the target staging host and real runtime env secrets.

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/authentik/blueprints/30-applications.yaml
 M deploy/env/00-global.env.example
 M deploy/env/README.md
 M deploy/runbooks/README.md
 M deploy/runbooks/backup-restore.md
 M deploy/runbooks/demo-data.md
 M deploy/runbooks/nextcloud-collabora.md
 M deploy/runbooks/v0.2-runtime-gate-1.md
 M deploy/scripts/00-create-directories.sh
 M deploy/scripts/02-bootstrap-postgres.sh
 M deploy/scripts/05-create-internal-ca-cert.sh
 M deploy/scripts/05-create-self-signed-cert.sh
 M deploy/scripts/06-configure-hosts.sh
 M deploy/scripts/52-seed-demo-data.sh
 M deploy/scripts/73-seed-nextcloud-document-hub.sh
 M deploy/scripts/90-backup-all.sh
 M deploy/scripts/91-backup-postgres.sh
 M deploy/scripts/96-check-all.sh
 M docs/v0.1/01-core-infrastructure.md
 M docs/v0.1/02-edge-nginx-tls.md
 M docs/v0.1/03-authentik-identity.md
 M docs/v0.1/README.md
 M history/INDEX.md
 M history/daily/2026-05-09.md
?? deploy/compose/grist/
?? deploy/data-model/lab-domain.v0.4.yaml
?? deploy/env/65-grist.env.example
?? deploy/nginx/conf.d/55-grist.conf
?? deploy/reports/v0.4-grist-research-workspace-validation.md
?? deploy/runbooks/grist.md
?? deploy/scripts/23-bootstrap-authentik-grist.sh
?? deploy/scripts/75-seed-grist-research-hub.sh
?? deploy/scripts/76-check-grist.sh
?? deploy/scripts/96-backup-grist.sh
?? docs/v0.1/14-v0.4-research-workspace.md
?? history/sessions/2026-05-09-112935-codex-implement-v0-4-grist-research-workspace.md
```
