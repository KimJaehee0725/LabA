# Plane Runbook

## Start

```bash
cd /srv/lab-platform/compose/plane
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/40-plane.env \
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

## Smoke

Create workspace, project, work item, page, and attachment. Confirm attachment object exists in `plane-uploads`.
