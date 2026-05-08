# Plane Compose Patch Notes

Plane changes its self-hosted Docker Compose layout across releases. This module is a platform patch target, not a replacement for release review.

Baseline captured for v0.2:

- Date: 2026-05-08
- Target env examples: `makeplane/*:v0.25.0`
- Platform patch: remove bundled Postgres, Redis, and MinIO; use shared `postgres`, `redis`, and `minio` on `lab_data`.

Before production use:

1. Compare this file with the Plane release compose for the selected tag.
2. Keep service names stable for Nginx: `plane-web`, `plane-api`, `plane-space`, `plane-admin`, `plane-live`.
3. Re-check supported OIDC environment variables for the selected tag; some Plane versions require configuring OIDC in God Mode instead.
4. Run `docker compose config` with real env files.
