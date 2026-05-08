# Core Runbook

## Start

```bash
cd /srv/lab-platform/compose/core
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  up -d
```

Bootstrap:

```bash
/srv/lab-platform/scripts/02-bootstrap-postgres.sh
/srv/lab-platform/scripts/03-bootstrap-minio.sh
/srv/lab-platform/scripts/04-check-core.sh
```

## Validation

- `postgres` passes `pg_isready`.
- `redis` returns `PONG`.
- `minio` health endpoint responds.
- Postgres, Redis, and MinIO ports are not published to the host.

## Rollback

Stop compose without removing volumes:

```bash
docker compose down
```
