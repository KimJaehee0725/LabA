# Change - Implement MLflow and Nextcloud document app wave

Date: 2026-05-09 04:32 +0000
Agent: codex
Status: completed

## Why

v0.3 current wave fixes scope to MLflow plus Nextcloud/Collabora document hub while deferring Overleaf and Gitea-native document integration.

## How

Added Authentik bootstrap automation for Nextcloud OIDC and MLflow Forward Auth/manual outpost, MLflow artifact smoke with Postgres and MinIO checks, Nextcloud app/OIDC/document hub seed/check scripts, enabled-service check gating, data-model seeds, runbooks, smoke docs, and validation report.

## Files

- deploy/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh; deploy/scripts/61-smoke-mlflow-artifact.sh; deploy/scripts/73-seed-nextcloud-document-hub.sh; deploy/data-model/lab-domain.v0.3.yaml

## Validation

- git diff --check; bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; python3 YAML/embedded Python checks; node --check embedded Playwright script; docker compose config for MLflow and Nextcloud examples; high-confidence secret scan

## Risks / Follow-Ups

Runtime smoke still needs deployment-host execution with real /srv/lab-platform/env values; MLflow external programmatic API auth and Overleaf remain deferred.

## Git Status Snapshot

```text
M deploy/README.md
 M deploy/data-model/lab-domain.v0.3.yaml
 M deploy/env/50-mlflow.env.example
 M deploy/env/60-nextcloud.env.example
 M deploy/env/README.md
 M deploy/reports/v0.3-smoke-report.md
 M deploy/runbooks/authentik.md
 M deploy/runbooks/mlflow.md
 M deploy/runbooks/nextcloud-collabora.md
 M deploy/runbooks/v0.3-smoke.md
 M deploy/scripts/60-check-mlflow.sh
 M deploy/scripts/70-install-nextcloud-apps.sh
 M deploy/scripts/71-configure-nextcloud-oidc.sh
 M deploy/scripts/72-check-nextcloud.sh
 M deploy/scripts/96-check-all.sh
 M docs/v0.1/06-mlflow-module.md
 M docs/v0.1/07-nextcloud-collabora-module.md
 M docs/v0.1/11-v0.3-smoke-test-plan.md
 M docs/v0.1/12-env-and-git-operations.md
 M docs/v0.1/13-data-model.md
 M history/INDEX.md
 M history/daily/2026-05-09.md
?? deploy/reports/v0.3-mlflow-nextcloud-app-wave-validation.md
?? deploy/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh
?? deploy/scripts/61-smoke-mlflow-artifact.sh
?? deploy/scripts/73-seed-nextcloud-document-hub.sh
?? deploy/scripts/74-smoke-nextcloud-browser.sh
?? history/sessions/2026-05-09-041024-codex-implement-v0-3-mlflow-nextcloud-document-app-wave.md
```
