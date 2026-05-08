# MLflow Runbook

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

Create Authentik Proxy Provider `mlflow-proxy` and a manual outpost token. Store the token in `50-mlflow.env`.

Unauthenticated browser access should return a redirect or denial from Authentik. Docker socket management is not used.

## Smoke

Run an internal MLflow experiment and confirm artifacts land in `s3://mlflow-artifacts`, not local container storage.
