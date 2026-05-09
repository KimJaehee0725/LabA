# Change - Validate internal CA TLS and Plane OIDC SSL verification

Date: 2026-05-09 03:54 +0000
Agent: codex
Status: completed

## Why

내부 CA TLS 전환과 Plane OIDC_VERIFY_SSL=1 런타임 상태를 다음 app wave 전에 검증 가능한 checkpoint로 고정해야 했다.

## How

OpenSSL/curl/Nginx/Plane/Auth scripts와 Playwright browser smoke를 수행하고 deploy/reports/v0.3-plane-tls-oidc-validation.md에 비밀값 없이 증거를 기록했다.

## Files

- deploy/reports/v0.3-plane-tls-oidc-validation.md
- deploy/scripts/05-create-internal-ca-cert.sh
- deploy/compose/plane/docker-compose.yml
- deploy/env/40-plane.env.example
- deploy/runbooks/edge-nginx.md
- deploy/runbooks/plane.md
- deploy/scripts/50-bootstrap-plane.sh
- history/daily/2026-05-09.md
- history/INDEX.md

## Validation

- git diff --check
- bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh
- openssl verify -CAfile /srv/lab-platform/nginx/ssl/lab-internal-ca.crt /srv/lab-platform/nginx/ssl/origin.crt
- curl --cacert lab-internal-ca.crt Authentik/Plane endpoints
- AUTHENTIK_CHECK_DISCOVERY_SLUGS=plane /srv/lab-platform/scripts/20-check-authentik.sh
- /srv/lab-platform/scripts/51-check-plane.sh
- Playwright Plane Authentik OIDC browser smoke reached /lab-demo

## Risks / Follow-Ups

- MLflow, Nextcloud/Collabora, Overleaf, and backup dry-run remain outside this checkpoint and must be handled in the next app wave.
- Browser smoke used Playwright `ignoreHTTPSErrors: true`; TLS trust itself was validated separately with OpenSSL and curl against the internal CA.

## Git Status Snapshot

```text
M deploy/compose/plane/docker-compose.yml
 M deploy/env/40-plane.env.example
 M deploy/runbooks/edge-nginx.md
 M deploy/runbooks/plane.md
 M deploy/scripts/50-bootstrap-plane.sh
 M history/INDEX.md
?? deploy/reports/v0.3-plane-tls-oidc-validation.md
?? deploy/scripts/05-create-internal-ca-cert.sh
?? history/daily/2026-05-09.md
```
