# Plane Runbook

## Prepare

Create `/srv/lab-platform/env/40-plane.env` from the example and generate all placeholder values on the server. Keep generated values out of git, history, and chat.

Set the Plane OIDC values in `40-plane.env` before running Plane bootstrap:

- `PLANE_OIDC_DISCOVERY_URL=https://auth.lab.snu.ac.kr/application/o/plane/.well-known/openid-configuration`
- `PLANE_OIDC_CLIENT_ID=plane`
- `PLANE_OIDC_CLIENT_SECRET=<generated Authentik provider secret>`
- `PLANE_OIDC_SCOPES="openid email profile groups"`
- `PLANE_OIDC_VERIFY_SSL=1` after the internal CA certificate is installed, or `0` only for early smoke with the self-signed edge certificate.
- `PLANE_OIDC_PROVIDER_LABEL=Authentik`

The Plane API container mounts `/srv/lab-platform/nginx/ssl/lab-internal-ca.crt` and sets `REQUESTS_CA_BUNDLE` so Python `requests` can verify Authentik HTTPS endpoints when `PLANE_OIDC_VERIFY_SSL=1`.

Create the Postgres role/database and MinIO service user after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
sudo /srv/lab-platform/scripts/08-create-minio-service-users.sh
```

Create or update the Authentik provider/application:

```bash
sudo /srv/lab-platform/scripts/21-bootstrap-authentik-plane-oidc.sh
sudo AUTHENTIK_CHECK_DISCOVERY_SLUGS=plane /srv/lab-platform/scripts/20-check-authentik.sh
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
  up --build -d
```

Review `README.patch-notes.md` against the selected Plane release before production.

Run bootstrap after Plane is up. It marks the instance as set up and synchronizes the OIDC keys from `40-plane.env` into Plane `InstanceConfiguration`, including `OIDC_VERIFY_SSL`.

```bash
sudo /srv/lab-platform/scripts/50-bootstrap-plane.sh
```

## OIDC

Provider:

- Client ID: `plane`
- Discovery URL: `https://auth.lab.snu.ac.kr/application/o/plane/.well-known/openid-configuration`
- Redirect URIs:
  - `https://lab.snu.ac.kr/auth/oidc/callback/`

The local custom Plane backend/web images add generic OIDC support on top of Plane `v0.25.0` from upstream ref `f70eae2f3be48b3cfb6ed579ef587c2a86a1c56b`. Store the generated client secret only in `/srv/lab-platform/env/40-plane.env`.

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
