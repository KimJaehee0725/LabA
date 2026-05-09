# Session - Implement v0.3 MLflow Nextcloud document app wave

Date: 2026-05-09 04:10 +0000
Agent: codex

## Scope

MLflow smoke, Nextcloud/Collabora app hub, Authentik bootstrap, runbooks, checks, reports

## Read First

- `history/CONTEXT.md`
- `history/daily/2026-05-09.md`
- `history/changes/2026-05-09-035429-validate-internal-ca-tls-and-plane-oidc-ssl-verification.md`

## Plan

- 기존 deploy script/runbook/style을 재사용한다.
- Authentik app bootstrap, MLflow artifact smoke, Nextcloud document hub seed/check를 구현한다.
- data-model, docs, report, history를 현재 wave 범위에 맞춘다.
- 정적 검증 후 로컬 commit을 만든다.

## Work Log

- `22-bootstrap-authentik-mlflow-nextcloud.sh`를 추가해 Nextcloud OIDC provider/application과 MLflow Proxy Provider/manual outpost를 자동화했다.
- `61-smoke-mlflow-artifact.sh`를 추가하고 `60-check-mlflow.sh`가 external auth gate, internal health, artifact smoke를 확인하도록 확장했다.
- Nextcloud app install/OIDC/check scripts를 Collectives/Tables/Deck/GitHub integration과 group provisioning 기준으로 확장했다.
- `73-seed-nextcloud-document-hub.sh`와 `74-smoke-nextcloud-browser.sh`를 추가했다.
- `lab-domain.v0.3.yaml`, module docs, runbooks, smoke report template, validation report를 갱신했다.
- `git diff --check`, `bash -n`, embedded Python/JS syntax checks, compose config render, touched-file secret scan을 통과했다.

## End Summary

- 구현 파일은 준비되었고 runtime smoke는 실제 `/srv/lab-platform/env/*.env` 값과 실행 중인 containers가 있는 서버에서 수행해야 한다.
- Overleaf와 Gitea-native document integration은 이 wave에서 deferred로 유지한다.
