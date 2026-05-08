# Gitea Runbook

## Start

```bash
cd /srv/lab-platform/compose/gitea
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/30-gitea.env \
  up -d
```

## OIDC

Create an Authentik provider:

- Client ID: `gitea`
- Redirect URI: `https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback`
- Discovery URL in Gitea: `https://auth.lab.snu.ac.kr/application/o/gitea/.well-known/openid-configuration`

Keep normal registration disabled. Start with `ACCOUNT_LINKING = login` unless email trust and group policy are confirmed.

## Smoke

1. Log in with Authentik.
2. Create a private repo.
3. Push over SSH to port `2222`.
4. Push a Git LFS object.
5. Confirm the object exists in MinIO bucket `gitea-lfs`.
