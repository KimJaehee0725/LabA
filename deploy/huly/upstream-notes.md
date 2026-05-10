# Huly Upstream Notes

Source: <https://github.com/hcengineering/huly-selfhost>

Observed on 2026-05-10 at commit `767fd47adcd0d521a02958e09da057635082d55a`.

## Runtime Shape

- Core app services: `front`, `account`, `transactor`, `workspace`, `collaborator`, `fulltext`, `rekoni`, `stats`, `kvs`.
- Core data services: CockroachDB, Redpanda, Elasticsearch, MinIO.
- Optional Phase 3 services: `github` for bidirectional GitHub sync, `calendar` plus MongoDB for Google Calendar.
- The upstream compose includes its own Nginx. LabA keeps the existing edge Nginx and proxies directly to Huly services on `labstack_backend`.

## External Routes

- `/` -> `huly-front:8080`
- `/_accounts` -> `huly-account:3000`
- `/_transactor` -> `huly-transactor:3333` with WebSocket support
- `/_collaborator` -> `huly-collaborator:3078` with WebSocket support
- `/_rekoni` -> `huly-rekoni:4004`
- `/_stats` -> `huly-stats:4900`
- `/_github` -> `huly-github:3500` when the `github` profile is enabled
- `/_calendar` -> `huly-calendar:8095` when the `calendar` profile is enabled
- `/files` -> `huly-minio:9000`

## Auth And Integrations

- OIDC is configured on the `account` service with `OPENID_CLIENT_ID`, `OPENID_CLIENT_SECRET`, and `OPENID_ISSUER`.
- Because LabA exposes account behind `/_accounts`, the Authentik redirect URI is `https://huly.lab.example.ac.kr/_accounts/auth/openid/callback`.
- GitHub App sync requires App ID, App slug, Client ID, Client secret, private key, and webhook secret.
- Google Calendar requires a Google OAuth web application credential JSON and redirect URI `https://huly.lab.example.ac.kr/_calendar/signin/code`.
