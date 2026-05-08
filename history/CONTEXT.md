# Project Context

Last updated: 2026-05-08

## Research Goal

- Build a secure self-hosted lab platform on Ubuntu with Docker Compose.
- v0.3 target: first integrated implementation is running and passes smoke tests.
- v0.2 target: generate module implementation files.
- v0.1 target: detailed module-level planning.

## Current Architecture Or Structure

- Planning docs live in `docs/`.
- v0 blueprint lives in `docs/v0/`.
- v0.1 detailed planning lives in `docs/v0.1/`.
- Planned services: Authentik, Plane, Gitea, MLflow, Nextcloud, Collabora, Overleaf CE, MinIO, Postgres, Redis, Nginx.
- Default deployment path remains `/srv/lab-platform`.

## Current Decisions

- Use shared core infrastructure for Postgres, Redis, MinIO, and Nginx.
- Keep Nginx as the only public HTTP/S entrypoint.
- Use Authentik as the central identity provider with MFA.
- Use Authentik Forward Auth for MLflow UI.
- Use Nextcloud `user_oidc` rather than `oidc_login`.
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
- Backup offsite location and retention policy are unresolved.
- MinIO OIDC policy mapping is unresolved.
- Authentik provider secrets must not be recorded in docs/history/git.

## Next Steps

- Begin v0.2 with repository/deploy skeleton, `.env.example`, core compose, and Nginx skeleton.
- Then implement Authentik compose/blueprints before app modules.
- History BM25 recall is now usable because `numpy` is installed in the Python 3.12 user site.
