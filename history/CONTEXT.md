# Project Context

Last updated: 2026-05-09

## Research Goal

- Build a secure self-hosted lab platform on Ubuntu with Docker Compose.
- v0.4 target: add a strict-OSS research workspace MVP with Grist as the structured database/dashboard layer.
- v0.3 target: first integrated implementation is running and passes smoke tests.
- v0.2 target: generate module implementation files.
- v0.1 target: detailed module-level planning.

## Current Architecture Or Structure

- Planning docs live in `docs/`.
- v0 blueprint lives in `docs/v0/`.
- v0.1 detailed planning lives in `docs/v0.1/`.
- Planned services: Authentik, Plane, Gitea, MLflow, Nextcloud, Collabora, Grist, Overleaf CE, MinIO, Postgres, Redis, Nginx.
- Default deployment path remains `/srv/lab-platform`.
- Current implemented app waves include core/edge/Auth/Gitea/Plane plus MLflow, Nextcloud/Collabora, and Grist deployment, bootstrap, seed, and smoke scripts.

## Current Decisions

- Use shared core infrastructure for Postgres, Redis, MinIO, and Nginx.
- Keep Nginx as the only public HTTP/S entrypoint.
- Use Authentik as the central identity provider with MFA.
- Use Authentik Forward Auth for MLflow UI.
- Use Nextcloud `user_oidc` rather than `oidc_login`.
- Treat Nextcloud as a document/research hub for v0.3 with Files/Office, Collectives, Tables, Deck, Calendar/Tasks, group folders, and user-scoped GitHub integration.
- Treat Grist as the v0.4 canonical structured research database/dashboard layer; Nextcloud Tables remains installed but is not canonical.
- Keep Plane as canonical for work items and Nextcloud Collectives as canonical for pages/wiki.
- Keep GitHub PAT/OAuth setup user-scoped; v0.4 stores explicit GitHub URL references only.
- Keep Overleaf CE on manual accounts for v0.3; LDAP/SSO is later.
- Keep Nextcloud local disk storage for v0.2/v0.3 unless the user changes the storage decision.

## Active Ideas

- v0.2 implementation should follow `docs/v0.1/10-v0.2-implementation-backlog.md`.
- v0.3 smoke testing should follow `docs/v0.1/11-v0.3-smoke-test-plan.md`.
- Use service-specific MinIO access keys/policies instead of root credentials.
- Keep deployment files separate from real secrets.
- Use split env files under `/srv/lab-platform/env/` instead of one oversized `.env`.
- Commit at module checkpoints and use feature branches/worktrees when v0.2 work becomes parallel or risky.

## Open Questions And Risks

- Actual domain and TLS issuance method are still placeholders.
- MLflow programmatic API authentication for training nodes is unresolved.
- Grist OIDC redirect, external Nginx route, and integrated v0.4 smoke still need to be executed on the deployment host with real `/srv/lab-platform/env/*.env` values.
- Backup offsite location and retention policy are unresolved.
- MinIO OIDC policy mapping is unresolved.
- Authentik provider secrets must not be recorded in docs/history/git.

## Next Steps

- On the deployment host, generate real `65-grist.env`, run Postgres/Auth bootstrap, start Grist, seed `Lab Research Hub`, then run `76-check-grist.sh` and `96-check-all.sh` with `ENABLED_SERVICES=core,edge,authentik,gitea,plane,mlflow,nextcloud,grist`.
- Keep Overleaf deferred until the next app wave.
