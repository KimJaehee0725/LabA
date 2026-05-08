# Plane Compose Patch Notes

Plane changes its self-hosted Docker Compose layout across releases. This module is a platform patch target, not a replacement for release review.

Baseline captured for v0.2:

- Date: 2026-05-08
- Target env examples: `makeplane/*:v0.25.0`
- Platform patch: remove bundled Postgres, Redis, and MinIO; use shared `postgres`, `redis`, and `minio` on `lab_data`.
- Auth patch: build local backend/web images from `makeplane/plane@f70eae2f3be48b3cfb6ed579ef587c2a86a1c56b` with `deploy/compose/plane/custom/patches/plane-authentik-oidc.patch`.

Before production use:

1. Compare this file with the Plane release compose for the selected tag.
2. Keep service names stable for Nginx: `plane-web`, `plane-api`, `plane-space`, `plane-admin`, `plane-live`.
3. Re-check `plane-authentik-oidc.patch` with `git apply --check --unidiff-zero` against the selected tag before changing `PLANE_SOURCE_REF`.
4. Run `docker compose config` with real env files.
