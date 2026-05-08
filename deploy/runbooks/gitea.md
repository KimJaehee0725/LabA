# Gitea Runbook

## Prepare

Create `/srv/lab-platform/env/30-gitea.env` from the example and generate all placeholder values on the server. Keep the generated values out of git, history, and chat.

Create the Postgres role/database and MinIO service user after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
sudo /srv/lab-platform/scripts/08-create-minio-service-users.sh
```

## Start

```bash
cd /srv/lab-platform/compose/gitea
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/30-gitea.env \
  --env-file /srv/lab-platform/env/80-minio-policies.env \
  -f /srv/lab-platform/compose/gitea/docker-compose.yml \
  up -d
```

## OIDC

Create an Authentik provider:

- Client ID: `gitea`
- Redirect URI: `https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback`
- Discovery URL in Gitea: `https://auth.lab.snu.ac.kr/application/o/gitea/.well-known/openid-configuration`

Keep normal registration disabled. Start with `ACCOUNT_LINKING = login` unless email trust and group policy are confirmed.
Store the generated client secret only in `/srv/lab-platform/env/30-gitea.env`.

After the Authentik provider exists, add `gitea` to `AUTHENTIK_CHECK_DISCOVERY_SLUGS` in `/srv/lab-platform/env/20-authentik.env` and run:

```bash
sudo /srv/lab-platform/scripts/20-check-authentik.sh
```

## Check

```bash
sudo /srv/lab-platform/scripts/41-check-gitea.sh
sudo ALLOW_GITEA_SSH=true /srv/lab-platform/scripts/10-check-edge.sh
```

## Smoke

1. Log in with Authentik.
2. Create a private repo.
3. Push over SSH to port `2222`.
4. Push a Git LFS object.
5. Confirm the object exists in MinIO bucket `gitea-lfs`.
