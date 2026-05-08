# Plane Runbook

## Prepare

Create `/srv/lab-platform/env/40-plane.env` from the example and generate all placeholder values on the server. Keep generated values out of git, history, and chat.

Create the Postgres role/database and MinIO service user after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
sudo /srv/lab-platform/scripts/08-create-minio-service-users.sh
```

## Start

```bash
cd /srv/lab-platform/compose/plane
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/40-plane.env \
  --env-file /srv/lab-platform/env/80-minio-policies.env \
  -f /srv/lab-platform/compose/plane/docker-compose.yml \
  up -d
```

Review `README.patch-notes.md` against the selected Plane release before production.

## OIDC

Provider:

- Client ID: `plane`
- Redirect URIs:
  - `https://lab.snu.ac.kr/auth/oidc/callback/`
  - `https://lab.snu.ac.kr/api/auth/oidc/callback/`

If the selected Plane tag does not support env-driven OIDC, configure it in God Mode and record that decision.
Store the generated client secret only in `/srv/lab-platform/env/40-plane.env`.

After the Authentik provider exists, add `plane` to `AUTHENTIK_CHECK_DISCOVERY_SLUGS` in `/srv/lab-platform/env/20-authentik.env` and run:

```bash
sudo /srv/lab-platform/scripts/20-check-authentik.sh
```

## Check

```bash
sudo /srv/lab-platform/scripts/51-check-plane.sh
sudo ALLOW_GITEA_SSH=true /srv/lab-platform/scripts/10-check-edge.sh
```

## Smoke

Create workspace, project, work item, page, and attachment. Confirm attachment object exists in `plane-uploads`.
