# Authentik Runbook

## Start

```bash
cd /srv/lab-platform/compose/authentik
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/20-authentik.env \
  up -d
```

Open `https://auth.lab.snu.ac.kr/if/flow/initial-setup/` for first setup.

## Blueprints

Blueprint files are mounted into `/blueprints/` in the Authentik containers and should be visible under System -> Blueprints. Apply or import:

- `authentik/blueprints/10-groups.yaml`
- `authentik/blueprints/20-oauth-scopes.yaml`
- `authentik/blueprints/30-applications.yaml`
- `authentik/blueprints/40-policies.yaml`

Create OAuth2 providers in the Authentik UI, then store generated client secrets only in `/srv/lab-platform/env/*.env`.

## Required Groups

- `lab-admin`
- `lab-member`
- `lab-collab`
- `lab-guest`

Docker socket mounts are intentionally absent.

## Check

```bash
/srv/lab-platform/scripts/20-check-authentik.sh
```

The check verifies reachability and confirms that the required groups exist through the Authentik API. Keep `AUTHENTIK_BOOTSTRAP_TOKEN` only in `/srv/lab-platform/env/20-authentik.env`.
