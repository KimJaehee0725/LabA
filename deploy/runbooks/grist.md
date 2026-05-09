# Grist Runbook

## Prepare

Create `/srv/lab-platform/env/65-grist.env` from the example and generate all placeholder values on the server. Keep `GRIST_OIDC_CLIENT_SECRET`, `GRIST_SESSION_SECRET`, `GRIST_BOOT_KEY`, and any `GRIST_SEED_API_KEY` out of git, reports, history, and chat.

The pinned upstream release is `v1.7.13`, but the Docker image tag omits the leading `v`:

```text
GRIST_IMAGE=gristlabs/grist-oss:1.7.13
GRIST_RELEASE=v1.7.13
```

Create the Postgres role/database after the env file is ready:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
```

Create or update the Authentik OIDC provider/application. The redirect URI must stay:

```text
https://data.lab.snu.ac.kr/oauth2/callback
```

Run:

```bash
sudo /srv/lab-platform/scripts/23-bootstrap-authentik-grist.sh
sudo AUTHENTIK_CHECK_DISCOVERY_SLUGS=grist /srv/lab-platform/scripts/20-check-authentik.sh
```

## Start

```bash
cd /srv/lab-platform/compose/grist
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/65-grist.env \
  up -d
```

Grist uses the shared Postgres and Redis services and stores `.grist` document files under `/srv/lab-platform/data/grist/persist`.

Strict defaults in `65-grist.env` force login, disable anonymous playgrounds, disable non-admin org creation, disable personal orgs, and prefer `gvisor` sandboxing. If the host does not have `runsc`/gVisor installed, set `GRIST_SANDBOX_FLAVOR` explicitly during host hardening rather than silently weakening the runtime.

## Research Hub Seed

Install the v0.4 catalog and seed the structured workspace:

```bash
sudo install -d -m 0755 /srv/lab-platform/data-model
sudo install -m 0644 deploy/data-model/lab-domain.v0.4.yaml /srv/lab-platform/data-model/lab-domain.v0.4.yaml
sudo /srv/lab-platform/scripts/75-seed-grist-research-hub.sh
```

The seed creates or updates workspace/document `Lab Research Hub` with `People`, `Teams`, `Projects`, `Pages`, `Tasks`, `Resources`, `Papers`, `Datasets`, `Experiments`, `GitHubRefs`, `Events`, and `DashboardPages`.

For ongoing operations, prefer a user or service account API key in `GRIST_SEED_API_KEY`. `GRIST_BOOT_KEY` is accepted for bootstrap only and is sent as the `X-Boot-Key` header.

## Smoke

```bash
sudo /srv/lab-platform/scripts/76-check-grist.sh
```

The check confirms:

- internal `/status` from the Grist container
- external `https://data.lab.snu.ac.kr/status`
- unauthenticated root access redirects or is denied
- Authentik discovery for application slug `grist`
- API access to the seeded workspace/document
- required v0.4 tables and seeded records
- `DashboardPages` includes dashboard, card, and calendar-style entries

The integrated v0.4 smoke uses:

```bash
sudo ENABLED_SERVICES=core,edge,authentik,gitea,plane,mlflow,nextcloud,grist \
  /srv/lab-platform/scripts/96-check-all.sh
```

## GitHub Policy

Keep Nextcloud `integration_github` enabled for dashboard/search/link previews, but user PAT/OAuth setup belongs only in each user's Connected accounts. Do not store GitHub PATs in server env, reports, history, seed data, Plane, Grist, or Collectives templates.

For strict OSS, v0.4 does not depend on Plane Commercial GitHub integration. Use explicit GitHub URL/reference fields in Plane, Grist, and Collectives.

## Backup

Postgres backups include the `grist` database. File backups include `/srv/lab-platform/data/grist/persist` through:

```bash
sudo /srv/lab-platform/scripts/96-backup-grist.sh --dry-run
```

The full backup dry-run calls the same Grist persist backup:

```bash
sudo /srv/lab-platform/scripts/90-backup-all.sh --dry-run
```
