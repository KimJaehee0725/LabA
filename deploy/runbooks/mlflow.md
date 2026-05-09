# MLflow Runbook

## Prepare

Create `/srv/lab-platform/env/50-mlflow.env` from the example and generate all placeholder values on the server. Keep real DB passwords, MinIO access keys, and Authentik outpost tokens out of git, history, and chat.

Create the Postgres role/database and MinIO bucket/service user after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
sudo /srv/lab-platform/scripts/03-bootstrap-minio.sh
sudo /srv/lab-platform/scripts/08-create-minio-service-users.sh
```

Create or update the Authentik Proxy Provider and manual outpost. The script also writes the generated outpost token into `/srv/lab-platform/env/50-mlflow.env` without printing it:

```bash
sudo /srv/lab-platform/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh
```

MLflow remains protected with Authentik Forward Auth for browser access. The internal experiment/artifact smoke uses `http://127.0.0.1:5000` inside the MLflow container so v0.3 does not depend on external programmatic API authentication.

## Build And Start

```bash
cd /srv/lab-platform/compose/mlflow
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/50-mlflow.env \
  build
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/50-mlflow.env \
  up -d
```

## Auth

Provider/outpost values:

- Authentik Proxy Provider: `mlflow-proxy`
- Outpost: `mlflow-outpost`
- External host: `https://mlflow.lab.snu.ac.kr`
- Runtime upstream: `http://mlflow:5000` through Nginx

Unauthenticated browser access should return a redirect or denial from Authentik. Docker socket management is not used.

## Smoke

```bash
sudo /srv/lab-platform/scripts/60-check-mlflow.sh
```

The check confirms:

- external unauthenticated access is gated by Authentik
- the internal MLflow server responds
- a smoke experiment/run/param/metric/artifact can be created
- run metadata exists in Postgres
- the smoke artifact object exists in MinIO bucket `mlflow-artifacts`

Set `MLFLOW_SKIP_ARTIFACT_SMOKE=true` only when debugging the auth gate separately from the tracking backend.
