# Lab Platform Deploy

This directory contains deployment documentation and tracked examples for the lab self-hosted platform.

## Phase 1 Host Skeleton Scope

Phase 1 is repo + dry-run only. It documents the host layout, Docker network names, example env files, and validation commands that will be used later, but it does not deploy live services or store real secrets.

The active deploy root for the Huly workspace MVP is `/opt/lab-stack`. Repository files may be copied or synced into that root during a controlled host dry-run, with real environment files created from `deploy/env/*.env.example` and stored outside git.

See `deploy/runbooks/phase1-host-skeleton.md` for the Phase 1 dry-run procedure.

Active Phase 1 Docker networks:

```text
labstack_public
labstack_backend
labstack_data
```

The older Plane, Gitea, Nextcloud, and MLflow compose/env/runbook material remains historical reference only unless a later decision explicitly reactivates it. Those services are not part of the active Phase 1 order.

## Layout

```text
deploy/
  authentik/blueprints/       Authentik group, scope, app, and policy skeletons
  compose/                    Module-scoped Docker Compose projects
  env/                        Tracked example env files only
  huly/                       Phase 3 upstream notes and pilot seed artifacts
  gitea/                      Legacy Gitea app.ini template, inactive in Phase 1
  minio/policies/             Service bucket policy templates
  nginx/                      Edge Nginx config, snippets, and route skeletons
  reports/                    Smoke report templates
  runbooks/                   Module runbooks
  scripts/                    Bootstrap, check, and backup scripts
```

## Phase 1 Dry-Run Order

1. Confirm `/opt/lab-stack` is the target runtime root in docs and scripts before any host work.
2. Create or dry-run the root subdirectories for compose files, env files, certs, Nginx config, service placeholders, logs, and backups.
3. Create or dry-run only the active networks: `labstack_public`, `labstack_backend`, and `labstack_data`.
4. Render or lint compose/env examples without starting long-running services.
5. Verify tracked env files contain placeholders only.
6. Record dry-run evidence in a report without including host secrets, private keys, tokens, or generated credentials.

Edge/Auth, Huly, shared MinIO storage, HF-like UI, Overleaf, MLflow, backup,
restore, and monitoring deployment happen in later phases. Plane, Gitea, and
Nextcloud are excluded from the active Phase 1 order.

## Phase 1 Validation Commands

```bash
bash -n deploy/scripts/00-create-directories.sh \
  deploy/scripts/01-create-networks.sh \
  deploy/scripts/09-check-host-readiness.sh \
  deploy/scripts/lib/common.sh

DRY_RUN=true LAB_STACK_ROOT=/opt/lab-stack \
  deploy/scripts/00-create-directories.sh

DRY_RUN=true \
  deploy/scripts/01-create-networks.sh

DRY_RUN=true \
  deploy/scripts/09-check-host-readiness.sh
```

## Secret Policy

Only example files are tracked here. Do not commit real `.env`, TLS private keys, client secrets, tokens, activation URLs, or generated service-account credentials.

Use placeholders such as `change-me-generate-on-server` in tracked files. Store actual values under `/opt/lab-stack/env/` with restricted permissions when a later phase performs real host deployment.

Phase 4 promotes the shared core `minio` service as the active storage layer.
Use `deploy/runbooks/phase4-minio-storage.md` after Phase 2 Edge/Auth and the
conditional Phase 3 Huly runtime are in place. Huly's internal `huly-minio`
container remains Huly-only and is not the shared storage endpoint.

Phase 7 uses `deploy/runbooks/phase7-operational-baseline.md` to close internal
backup, restore rehearsal, disk/cert, permission, service exposure, and
repo-facing secret hygiene checks that do not require new external credentials
or real DNS/TLS/SMTP inputs.

Phase 8 uses `deploy/runbooks/mlflow.md` to start an internal MLflow Tracking
MVP on shared Postgres and shared MinIO `lab-artifacts/mlflow`. Its public route
is tracked as an Authentik-gated disabled template until strict edge evidence is
available.
