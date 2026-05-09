# Nextcloud And Collabora Runbook

## Prepare

Create `/srv/lab-platform/env/60-nextcloud.env` from the example and generate all placeholder values on the server. Keep the admin password, OIDC client secret, Collabora admin password, and any seed app password out of git, history, and chat.

Create the Postgres role/database after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
```

Create or update the Authentik OIDC provider/application. The redirect URI must stay:

```text
https://files.lab.snu.ac.kr/apps/user_oidc/code
```

Run:

```bash
sudo /srv/lab-platform/scripts/22-bootstrap-authentik-mlflow-nextcloud.sh
sudo AUTHENTIK_CHECK_DISCOVERY_SLUGS=nextcloud /srv/lab-platform/scripts/20-check-authentik.sh
```

## Start

```bash
cd /srv/lab-platform/compose/nextcloud
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/60-nextcloud.env \
  up -d
```

Install apps:

```bash
/srv/lab-platform/scripts/70-install-nextcloud-apps.sh
```

Configure OIDC and Collabora:

```bash
/srv/lab-platform/scripts/71-configure-nextcloud-oidc.sh
```

The OIDC provider uses:

- scopes: `openid email profile groups`
- group provisioning: enabled
- group whitelist: `^lab-(admin|member|collab|guest)$`
- login restriction to whitelisted groups: enabled

Collabora uses the external CODE container. Do not install or enable built-in CODE (`richdocumentscode`).

## Document Hub Seed

Install and configure the document hub apps, then seed the v0.3 baseline:

```bash
sudo NEXTCLOUD_SEED_APP_PASSWORD=<runtime app password> \
  /srv/lab-platform/scripts/73-seed-nextcloud-document-hub.sh
```

The seed creates or updates:

- group `lab-member`
- group folder `Lab Demo Documents`
- folders `00-inbox`, `01-meeting-notes`, `02-literature`, `03-slides`, `04-reports`
- Collectives baseline `Lab Knowledge Base`
- Tables baseline `Research Resources`
- Deck board `Research Ops`
- Calendar `research-demo`

The GitHub integration app is installed and enabled, but GitHub PAT/OAuth setup stays user-scoped under Nextcloud Connected accounts. Do not store GitHub tokens in `/srv/lab-platform/env/`.

## Smoke

```bash
sudo NEXTCLOUD_SMOKE_PASSWORD=<runtime app password> \
  /srv/lab-platform/scripts/72-check-nextcloud.sh
```

The check covers `status.php`, `occ status`, enabled apps, `user_oidc` provider output, group folder presence, Collabora discovery, and optional WebDAV upload/download when a runtime password is supplied.

For UI smoke, log in through Authentik and confirm these entry points load:

- Files -> `Lab Demo Documents`
- Collectives -> `Lab Knowledge Base`
- Tables -> `Research Resources`
- Deck -> `Research Ops`
- Calendar

Optional Playwright browser smoke:

```bash
sudo NEXTCLOUD_BROWSER_PASSWORD=<demo password> \
  /srv/lab-platform/scripts/74-smoke-nextcloud-browser.sh
sudo NEXTCLOUD_BROWSER_TARGET=collectives NEXTCLOUD_BROWSER_PASSWORD=<demo password> \
  /srv/lab-platform/scripts/74-smoke-nextcloud-browser.sh
```

Where feasible, create a docx in the group folder, open it through Collabora, edit it, and confirm the saved file remains downloadable.
