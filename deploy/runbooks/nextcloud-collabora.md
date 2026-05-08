# Nextcloud And Collabora Runbook

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

Configure OIDC after the Authentik client secret is available:

```bash
source /srv/lab-platform/env/60-nextcloud.env
/srv/lab-platform/scripts/71-configure-nextcloud-oidc.sh
```

## Smoke

Check `status.php`, log in via OIDC, upload/download a file, create a docx, edit through Collabora, and confirm save.
