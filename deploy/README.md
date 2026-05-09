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

Edge/Auth, Huly, MinIO, HF-like UI, Overleaf, backup, and monitoring deployment happen in later phases. Plane, Gitea, Nextcloud, and MLflow are excluded from the active Phase 1 order.

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
