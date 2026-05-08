# Change - Plane Authentik OIDC custom image 추가

Date: 2026-05-08 18:06 +0000
Agent: codex
Status: completed

## Why

Plane v0.25.0에는 generic OIDC가 없어 v0.3의 Authentik-first Plane 로그인 경로가 막혀 있었다.

## How

고정된 Plane upstream ref 기반 backend/web patch build를 추가하고, backend OIDC route와 instance config field, OIDC Account provider choice/migration, web 로그인 버튼, Authentik provider bootstrap, OIDC smoke check, env/runbook/catalog 갱신을 연결했다. Staging self-signed TLS 때문에 `OIDC_VERIFY_SSL` 옵션도 추가했다. Plane local email/password는 break-glass 용도로 유지했다.

## Files

- deploy/compose/plane/docker-compose.yml
- deploy/compose/plane/custom/Dockerfile.backend
- deploy/compose/plane/custom/Dockerfile.web
- deploy/compose/plane/custom/patches/plane-authentik-oidc.patch
- deploy/scripts/21-bootstrap-authentik-plane-oidc.sh
- deploy/scripts/51-check-plane.sh
- deploy/env/40-plane.env.example
- deploy/runbooks/plane.md
- deploy/data-model/lab-domain.v0.3.yaml
- docs/v0.1/03-authentik-identity.md
- docs/v0.1/05-plane-module.md

## Validation

- `bash -n deploy/scripts/20-check-authentik.sh deploy/scripts/21-bootstrap-authentik-plane-oidc.sh deploy/scripts/50-bootstrap-plane.sh deploy/scripts/51-check-plane.sh`
- Plane env example 기반 `docker compose config`
- `makeplane/plane@f70eae2f3be48b3cfb6ed579ef587c2a86a1c56b` 대상 `git apply --check --unidiff-zero`
- backend/web custom image `docker build`
- backend image 안에서 OIDC patch 대상 Python 파일과 OIDC provider migration `py_compile`
- staging runtime: Authentik provider bootstrap, custom Plane image rebuild/up, `50-bootstrap-plane.sh`, `51-check-plane.sh`
- staging browser: headless Chromium confirmed `Continue with Authentik` is visible and redirects to Authentik authentication flow
- `git diff --check`
- tracked secret scan: `rg -n "(password|token|secret).*=" deploy docs history --glob '!history/archive/**'`

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/plane/README.patch-notes.md
 M deploy/compose/plane/docker-compose.yml
 M deploy/data-model/lab-domain.v0.3.yaml
 M deploy/env/40-plane.env.example
 M deploy/runbooks/demo-data.md
 M deploy/runbooks/plane.md
 M deploy/scripts/50-bootstrap-plane.sh
 M deploy/scripts/51-check-plane.sh
 M docs/v0.1/03-authentik-identity.md
 M docs/v0.1/05-plane-module.md
 M docs/v0.1/13-data-model.md
 M docs/v0/03-service-plan.md
 M history/INDEX.md
 M history/daily/2026-05-08.md
?? deploy/compose/plane/custom/
?? deploy/scripts/21-bootstrap-authentik-plane-oidc.sh
?? history/changes/2026-05-08-180602-add-plane-authentik-oidc-custom-images.md
```
