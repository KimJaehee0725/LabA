# Phase 1 Host Skeleton

Phase 1 prepares the Huly workspace MVP deploy surface without creating live services.
It is repo + dry-run only.

## Scope

Active root and networks:

```text
LAB_STACK_ROOT=/opt/lab-stack
labstack_public
labstack_backend
labstack_data
```

Phase 1 creates or validates only the host skeleton:

- deploy/env examples with placeholders only
- `/opt/lab-stack` directory plan
- Huly stack service placeholder directories
- Nginx config/snippet directories
- backup and log directories
- Docker network names
- host readiness check commands

It does not start Authentik, Huly, MinIO, HF UI, Overleaf, Nginx, or any legacy service.

## Dry-Run Commands

Run from the repository root:

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

Expected dry-run output:

- `00-create-directories.sh` prints `install -d` commands under `/opt/lab-stack`.
- `01-create-networks.sh` prints `docker network create` commands for `labstack_public`, `labstack_backend`, and `labstack_data`.
- `09-check-host-readiness.sh` prints the checks it would perform and exits successfully without requiring the host to be prepared.

## Real Host Execution Boundary

Do not run non-dry-run commands until Phase 0 readiness has no blockers or explicitly approved pending items.

When a later phase performs real host execution, run the scripts on the target server only after copying tracked examples and creating server-only env files under `/opt/lab-stack/env`.

## Secret Policy

Do not commit real `.env` files, TLS private keys, client secrets, tokens, service-account credentials, SMTP credentials, or filled private readiness records.

Tracked files may contain placeholders and policy text only.

## Stop and Rollback

Phase 1 dry-runs are non-mutating, so rollback is normally unnecessary.

If a non-dry-run command is accidentally run during later host preparation:

1. Stop before starting any service.
2. Inspect `/opt/lab-stack` and the three `labstack_*` networks.
3. Preserve logs and command output for review.
4. Do not delete anything containing real secrets until it has been classified and backed up or securely destroyed.
