# Change - Validate MLflow and Nextcloud staging runtime

Date: 2026-05-09 10:48 +0000
Agent: codex
Status: passed

## Why

v0.3 app wave를 /srv/lab-platform staging runtime에 반영하고 MLflow artifact path와 Nextcloud/Collabora document hub를 실제 서비스 상태로 고정해야 했다.

## How

tracked deploy assets를 동기화하고 Postgres/MinIO/Auth bootstrap, MLflow/Nextcloud compose up, Nextcloud app install/config/seed, Authentik browser smoke, integrated 96-check-all을 수행했다. 검증 중 Nextcloud CA bundle, Authentik RS256 signing key, browser smoke multi-stage login, MLflow/MinIO smoke secret hygiene를 보강했다.

## Files

- deploy/reports/v0.3-mlflow-nextcloud-app-wave-validation.md
- deploy/reports/v0.3-smoke-report.md
- deploy/compose/nextcloud/docker-compose.yml
- deploy/compose/mlflow/docker-compose.yml
- deploy/nginx/conf.d/40-mlflow.conf
- deploy/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh
- deploy/scripts/60-check-mlflow.sh
- deploy/scripts/61-smoke-mlflow-artifact.sh
- deploy/scripts/71-configure-nextcloud-oidc.sh
- deploy/scripts/73-seed-nextcloud-document-hub.sh
- deploy/scripts/74-smoke-nextcloud-browser.sh

## Validation

- git diff --check; bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh; docker compose config for mlflow/nextcloud; /srv/lab-platform/scripts/96-check-all.sh with ENABLED_SERVICES=core,edge,authentik,gitea,plane,mlflow,nextcloud; Nextcloud Files/Collectives browser smoke

## Risks / Follow-Ups

Overleaf, Gitea-native 문서 연동, MLflow 외부 programmatic API auth, backup dry-run, 수동 Collabora `.docx` open/save는 deferred.

## Git Status Snapshot

```text
M deploy/compose/mlflow/docker-compose.yml
 M deploy/compose/nextcloud/docker-compose.yml
 M deploy/env/60-nextcloud.env.example
 M deploy/nginx/conf.d/40-mlflow.conf
 M deploy/reports/v0.3-mlflow-nextcloud-app-wave-validation.md
 M deploy/reports/v0.3-smoke-report.md
 M deploy/scripts/05-create-internal-ca-cert.sh
 M deploy/scripts/08-create-minio-service-users.sh
 M deploy/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh
 M deploy/scripts/60-check-mlflow.sh
 M deploy/scripts/61-smoke-mlflow-artifact.sh
 M deploy/scripts/71-configure-nextcloud-oidc.sh
 M deploy/scripts/73-seed-nextcloud-document-hub.sh
 M deploy/scripts/74-smoke-nextcloud-browser.sh
 M history/INDEX.md
 M history/daily/2026-05-09.md
?? deploy/compose/nextcloud/lab-ca.ini
?? history/sessions/2026-05-09-100613-codex-validate-v0-3-mlflow-nextcloud-staging-runtime.md
```
