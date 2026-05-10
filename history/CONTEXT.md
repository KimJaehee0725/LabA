# Project Context

Last updated: 2026-05-10

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
- Active deployment path is `/opt/lab-stack` for the Huly workspace MVP phases.

## Current Decisions

- Use shared core infrastructure for Postgres, Redis, MinIO, and Nginx.
- Keep Nginx as the only public HTTP/S entrypoint.
- Use Authentik as the central identity provider with MFA.
- Use Authentik Forward Auth for MLflow UI.
- Use Nextcloud `user_oidc` rather than `oidc_login`.
- Keep Overleaf CE on manual accounts for v0.3; LDAP/SSO is later.
- Keep Nextcloud local disk storage for v0.2/v0.3 unless the user changes the storage decision.
- Promote the shared core `minio` container as the Phase 4 storage layer; keep Huly's internal `huly-minio` dedicated to Huly.
- Map MinIO Console OIDC `policy` claims from Authentik groups: `lab-admin` -> `consoleAdmin`, `lab-member`/`lab-collab` -> `lab-storage-member-rw`, and no `lab-guest` Console access.
- Phase 5 adds a small HF-like catalog UI at `https://hf.lab.example.ac.kr`
  backed by shared Phase 4 MinIO buckets and a YAML metadata catalog.
- Phase 5.3 adds single-file direct upload for catalog model/dataset prefixes
  using `POST /api/files/presign?action=upload`, presigned S3 PUT URLs, default
  overwrite blocking, and MinIO CORS for `HF_UI_PUBLIC_URL`.
- Phase 6 Overleaf work is isolated on branch/worktree `huly/overleaf-mvp`
  at `/workspace/LargeProject/LabA-overleaf`; it is a direct Compose module
  with manual accounts, dedicated Mongo/Redis, shared Nginx routing, and no
  Authentik SSO in this phase.

## Active Ideas

- v0.2 implementation should follow `docs/v0.1/10-v0.2-implementation-backlog.md`.
- v0.3 smoke testing should follow `docs/v0.1/11-v0.3-smoke-test-plan.md`.
- Use service-specific MinIO access keys/policies instead of root credentials.
- Keep deployment files separate from real secrets.
- Use split env files under `/opt/lab-stack/env/` instead of one oversized `.env`.
- Keep Phase 5 staging automation behind explicit `HF_UI_ALLOW_STAGING_BYPASS`;
  disable it before strict/browser OIDC validation.
- Keep HF UI upload v1 limited to single-file direct PUT; multipart, folder, and
  resumable uploads are later phases.
- Keep Overleaf Phase 6 conditional-pass separate from Phase 2-5 full-pass:
  `LABSTACK_INCLUDE_OVERLEAF=true` opt-in is required for integrated checks.
- Commit at module checkpoints and use feature branches/worktrees when v0.2 work becomes parallel or risky.

## Open Questions And Risks

- Actual domain and TLS issuance method are still placeholders.
- MLflow programmatic API authentication for training nodes is unresolved.
- Backup offsite location and retention policy are unresolved.
- Phase 4 MinIO full pass remains conditional until real DNS/TLS and browser OIDC role evidence are available.
- Phase 5 HF-like UI full pass remains conditional until real DNS/TLS and
  browser OIDC evidence for `lab-member` and `lab-guest` are available.
- Phase 5.3 upload staging smoke passed on `/opt/lab-stack` with
  `STAGING_IP=127.0.0.1`: presigned PUT, CORS preflight, file-list refresh,
  uploaded JSONL preview, and duplicate HTTP 409 were confirmed.
- Phase 6 Overleaf runtime is not yet validated on `/opt/lab-stack`; local
  static checks passed, but image build, container startup, admin activation,
  SMTP delivery, and browser compile smoke remain pending.
- Authentik provider secrets must not be recorded in docs/history/git.

## Next Steps

- Begin v0.2 with repository/deploy skeleton, `.env.example`, core compose, and Nginx skeleton.
- Then implement Authentik compose/blueprints before app modules.
- History BM25 recall is now usable because `numpy` is installed in the Python 3.12 user site.
