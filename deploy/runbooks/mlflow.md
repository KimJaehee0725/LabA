# Phase 8 MLflow Runbook

Status: internal tracking MVP procedure; public UI remains disabled unless
Authentik gate evidence is available.

Phase 8 reactivates MLflow on the active `/opt/lab-stack` stack. It uses the
shared Postgres container for the backend store and the shared Phase 4 MinIO
`lab-artifacts/mlflow` prefix for artifacts. It does not publish a direct host
port.

## Prepare Env

Copy the example and replace generated secrets outside git:

```bash
sudo install -m 0640 deploy/env/50-mlflow.env.example \
  /opt/lab-stack/env/50-mlflow.env
sudoedit /opt/lab-stack/env/50-mlflow.env
```

Required values:

- `MLFLOW_DB_PASSWORD`
- `MLFLOW_S3_ACCESS_KEY`
- `MLFLOW_S3_SECRET_KEY`
- existing `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` from `10-core.env`

Default artifact root:

```text
s3://lab-artifacts/mlflow
```

## Bootstrap

Run after core Postgres, shared MinIO, and Phase 4 MinIO storage bootstrap:

```bash
sudo -E /opt/lab-stack/scripts/61-bootstrap-mlflow.sh
```

The bootstrap creates or updates:

- Postgres role/database for MLflow.
- MinIO policy for `lab-artifacts/mlflow/*`.
- MinIO service user for MLflow.

## Build And Start

```bash
cd /opt/lab-stack/compose/mlflow
sudo -E docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/10-core.env \
  --env-file /opt/lab-stack/env/35-minio-storage.env \
  --env-file /opt/lab-stack/env/50-mlflow.env \
  build

sudo -E docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/10-core.env \
  --env-file /opt/lab-stack/env/35-minio-storage.env \
  --env-file /opt/lab-stack/env/50-mlflow.env \
  up -d mlflow
```

## Check

Internal Phase 8 check:

```bash
PHASE8_REQUIRE_AUTH_GATE=false \
  sudo -E /opt/lab-stack/scripts/60-check-mlflow.sh
```

Integrated check:

```bash
LABSTACK_INCLUDE_MLFLOW=true \
PHASE8_REQUIRE_AUTH_GATE=false \
  sudo -E /opt/lab-stack/scripts/96-check-all.sh
```

The check creates a smoke experiment/run, logs a metric and artifact through
MLflow, and verifies the artifact exists in MinIO.

## Public UI

Do not expose MLflow directly. The tracked Nginx route is
`40-mlflow.conf.disabled` and must stay disabled until an Authentik proxy/outpost
is configured.

When Authentik gate values are available, enable the route and run:

```bash
MLFLOW_EDGE_ENABLED=true \
PHASE8_REQUIRE_AUTH_GATE=true \
STAGING_IP=127.0.0.1 \
  sudo -E /opt/lab-stack/scripts/60-check-mlflow.sh
```

Unauthenticated access must return `302`, `401`, or `403`.

## Backup And Restore

Enable MLflow backup only after the runtime has been bootstrapped:

```bash
LABSTACK_BACKUP_MLFLOW=true \
PHASE7_ALLOW_HULY_STOP=true \
  sudo -E /opt/lab-stack/scripts/90-backup-all.sh

LABSTACK_BACKUP_MLFLOW=true \
  sudo -E /opt/lab-stack/scripts/89-restore-rehearsal.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

The backup adds MLflow Postgres dump and `lab-artifacts/mlflow` artifact archive
entries to `manifest.tsv`.
