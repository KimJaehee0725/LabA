# Session - Validate v0.3 MLflow Nextcloud staging runtime

Date: 2026-05-09 10:06 +0000
Agent: codex

## Scope

staging /srv/lab-platform sync, runtime smoke, reports/history, local commit

## Read First

- `deploy/reports/v0.3-mlflow-nextcloud-app-wave-validation.md`
- `deploy/reports/v0.3-smoke-report.md`
- `history/changes/2026-05-09-104830-validate-mlflow-and-nextcloud-staging-runtime.md`

## Plan

- `b401a74` baseline에서 정적 검증을 재실행한다.
- tracked deploy assets만 `/srv/lab-platform`에 동기화한다.
- 기존 core/edge/Auth/Gitea/Plane preflight 통과 후 MLflow와 Nextcloud/Collabora를 bootstrap/start/smoke한다.
- Nextcloud document hub seed와 Authentik browser smoke를 실행한다.
- `96-check-all.sh`로 current wave를 통합 검증하고 report/history를 남긴다.

## Work Log

- `git diff --check`, `bash -n`, MLflow/Nextcloud compose config render가 통과했다.
- `/srv/lab-platform/env/50-mlflow.env`, `/srv/lab-platform/env/60-nextcloud.env`는 runtime env로만 사용했고 값은 report/history에 기록하지 않았다.
- Postgres DB, MinIO bucket/service user/policy bootstrap을 실행했다.
- Authentik Nextcloud OIDC provider/application과 MLflow proxy provider/outpost bootstrap을 실행했다.
- MLflow compose를 build/up하고 `60-check-mlflow.sh`를 통과시켰다.
- Nextcloud/Collabora compose를 up하고 app install, OIDC/Collabora config, document hub seed, `72-check-nextcloud.sh`를 통과시켰다.
- Browser smoke는 Files와 Collectives 모두 Authentik demo login 이후 도달했다.
- Final integrated smoke `96-check-all.sh`가 `core,edge,authentik,gitea,plane,mlflow,nextcloud` enabled set으로 통과했다.
- 검증 중 필요한 patch: Nextcloud CA bundle mount, Authentik OIDC RS256 signing key, browser smoke multi-stage login, MLflow/MinIO secret-safe smoke handling.

## End Summary

- Staging runtime validation passed on 2026-05-09.
- Evidence is recorded in `deploy/reports/v0.3-mlflow-nextcloud-app-wave-validation.md` and `deploy/reports/v0.3-smoke-report.md`.
- Latest integrated MLflow smoke run ID: `f408d9751ebf49e8a8d19f884800b16f`.
- HTTP evidence: MLflow unauthenticated external `302`, Nextcloud status `200`, Collabora discovery `200`, Authentik Nextcloud discovery `200`.
- Deferred: Overleaf, Gitea-native document integration, MLflow external programmatic API auth, backup dry-run, manual Collabora `.docx` open/save.
