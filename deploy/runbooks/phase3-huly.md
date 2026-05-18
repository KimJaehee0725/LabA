# Phase 3 Huly Pilot Runbook

This runbook deploys Huly self-host on the active `/opt/lab-stack` surface.
It assumes Phase 2 Edge/Auth is already running or conditionally running.

## Scope

- Huly domain: `huly.lab.example.ac.kr`
- Auth domain: `auth.lab.example.ac.kr`
- Runtime root: `/opt/lab-stack`
- Source baseline: `deploy/huly/upstream-version.txt`
- Active auth mode: Huly app-native OIDC through Authentik
- Fallback auth mode: disabled Authentik forward-auth config, used only if app-native OIDC blocks the pilot
- Included integrations: GitHub App sync and Google Calendar

## Server Preparation

1. Copy updated deploy files to `/opt/lab-stack`.
2. Create directories and fix permissions:

```bash
sudo /opt/lab-stack/scripts/00-create-directories.sh
```

3. Create `/opt/lab-stack/env/30-huly.env` from `deploy/env/30-huly.env.example`.
4. Generate server-only values. Use URL-safe values for values interpolated into URLs:

```bash
openssl rand -hex 32  # HULY_SERVER_SECRET
openssl rand -hex 24  # HULY_COCKROACH_PASSWORD
openssl rand -hex 24  # HULY_REDPANDA_ADMIN_PASSWORD
openssl rand -hex 24  # HULY_MINIO_ROOT_PASSWORD
```

5. In `/opt/lab-stack/env/20-authentik.env`, set:

```bash
HULY_OIDC_CLIENT_ID=huly
HULY_OIDC_CLIENT_SECRET=<generated-server-only-secret>
HULY_OIDC_REDIRECT_URIS=https://huly.lab.example.ac.kr/_accounts/auth/openid/callback
```

6. Re-bootstrap the Huly Authentik provider:

```bash
sudo /opt/lab-stack/scripts/22-bootstrap-authentik-oidc.sh
```

7. Store multiline integration secrets as files:

```bash
sudo install -m 0600 -o root -g root github-app.private-key.pem \
  /opt/lab-stack/secrets/huly/github-app.private-key.pem
sudo install -m 0600 -o root -g root google-calendar-oauth.json \
  /opt/lab-stack/secrets/huly/google-calendar-oauth.json
```

Set `HULY_GITHUB_PRIVATE_KEY_FILE` and
`HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE` in `30-huly.env`.

## Preflight

Strict full-pass mode:

```bash
sudo /opt/lab-stack/scripts/23-check-phase3-huly-preflight.sh
```

Staging mode with example domains and missing external OAuth credentials:

```bash
sudo PHASE3_REQUIRE_REAL_DOMAINS=false \
  PHASE3_REQUIRE_GITHUB=false \
  PHASE3_REQUIRE_CALENDAR=false \
  /opt/lab-stack/scripts/23-check-phase3-huly-preflight.sh
```

Preflight must pass before starting Huly. A relaxed staging pass is not a production pass.

## Start Huly

Core only:

```bash
sudo bash -lc '
set -a
. /opt/lab-stack/env/00-global.env
. /opt/lab-stack/env/10-core.env
. /opt/lab-stack/env/20-authentik.env
. /opt/lab-stack/env/30-huly.env
set +a
[[ -r "${HULY_GITHUB_PRIVATE_KEY_FILE:-}" ]] && export HULY_GITHUB_PRIVATE_KEY="$(cat "$HULY_GITHUB_PRIVATE_KEY_FILE")"
[[ -r "${HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE:-}" ]] && export HULY_GOOGLE_CALENDAR_CREDENTIALS="$(tr -d "\n" < "$HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE")"
docker compose -f /opt/lab-stack/compose/huly/docker-compose.yml up -d
'
```

Core plus GitHub and Calendar:

```bash
sudo bash -lc '
set -a
. /opt/lab-stack/env/00-global.env
. /opt/lab-stack/env/10-core.env
. /opt/lab-stack/env/20-authentik.env
. /opt/lab-stack/env/30-huly.env
set +a
[[ -r "${HULY_GITHUB_PRIVATE_KEY_FILE:-}" ]] && export HULY_GITHUB_PRIVATE_KEY="$(cat "$HULY_GITHUB_PRIVATE_KEY_FILE")"
[[ -r "${HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE:-}" ]] && export HULY_GOOGLE_CALENDAR_CREDENTIALS="$(tr -d "\n" < "$HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE")"
docker compose -f /opt/lab-stack/compose/huly/docker-compose.yml --profile github --profile calendar up -d
'
```

Reload Nginx after copying `20-huly.conf`:

```bash
sudo docker exec nginx nginx -t
sudo docker exec nginx nginx -s reload
```

Wait at least 60 seconds before runtime checks.

## Runtime Checks

```bash
sudo STAGING_IP=127.0.0.1 /opt/lab-stack/scripts/30-check-huly.sh
```

Expected:

- Huly core containers are running.
- Huly optional GitHub and Calendar containers are running when enabled.
- Huly containers publish no host ports.
- Nginx config is valid.
- `https://huly.lab.example.ac.kr/` returns HTTP 2xx, 3xx, or 4xx but not 5xx.
- `https://auth.lab.example.ac.kr/application/o/huly/.well-known/openid-configuration` is reachable.

## Browser Smoke

Use a private browser session.

1. Open `https://huly.lab.example.ac.kr`.
2. Confirm public workspace access is not available before login.
3. Use the Authentik/OpenID button to sign in.
4. Confirm the pilot workspace opens.
5. Confirm public signup is disabled or invite-only.
6. If app-native OIDC fails, do not edit the app data. Disable `20-huly.conf`, enable the reviewed forward-auth fallback config manually, reload Nginx, and record the OIDC failure in the report.

## Workspace Seed

Validate the seed bundle:

```bash
/opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh
```

Then create the workspace manually from `huly/seed/workspace.seed.yaml`.
The deterministic seed content is under:

- `/opt/lab-stack/huly/seed`
- `/opt/lab-stack/huly/notion-sample`

Do not import raw Notion exports or private research content into git.

## GitHub App

Create one GitHub App for the pilot.

- Callback URL: `https://huly.lab.example.ac.kr/github`
- Setup URL: `https://huly.lab.example.ac.kr/github?op=installation`
- Webhook URL: `https://huly.lab.example.ac.kr/_github/api/webhook`
- Permissions: Metadata read-only; Issues, Pull requests, Contents, Commit statuses, Projects, Webhooks read/write as required by Huly upstream.
- Events: Issues, Pull request, Pull request review, Pull request review comment, Pull request review thread.

Store all GitHub values only in `/opt/lab-stack/env/30-huly.env`.
Use one approved pilot repository for the first roundtrip test.

## Google Calendar

Create a Google OAuth web application credential.

- Redirect URI: `https://huly.lab.example.ac.kr/_calendar/signin/code`
- Enable Google Calendar API.
- Scopes to validate: calendar list readonly, userinfo email, calendars readonly, calendar events.
- Put the credential JSON in `HULY_GOOGLE_CALENDAR_CREDENTIALS` only on the server.

Calendar is a Phase 3 full-pass requirement. If credentials are unavailable,
record a conditional-pass with the missing Google console items.

## Report And Gate

Record evidence in `/opt/lab-stack/reports/phase3-huly-pilot.md`.

Full pass requires:

- OIDC login works without forward-auth fallback.
- Workspace seed is visible to two pilot users.
- Docs/wiki, chat, issue, calendar/project views work.
- Timeline/Gantt renders or an explicit fallback decision is logged.
- GitHub issue sync roundtrip works.
- Google Calendar event sync works.
- Notion sample scrub/import checklist is complete.
- Two pilot users use the workspace for one week and blockers are recorded.

Check the report:

```bash
sudo /opt/lab-stack/scripts/32-check-huly-pilot.sh
```

For current staging-only reviews:

```bash
sudo PHASE3_REQUIRE_PILOT_FULL_PASS=false /opt/lab-stack/scripts/32-check-huly-pilot.sh
```

## Rollback

Stop only Huly:

```bash
sudo docker compose \
  -f /opt/lab-stack/compose/huly/docker-compose.yml \
  --profile github \
  --profile calendar \
  down
```

Then remove or disable `20-huly.conf` and reload Nginx. Preserve:

- `/opt/lab-stack/data/huly`
- `/opt/lab-stack/logs/huly`
- `/opt/lab-stack/env/30-huly.env`
- `/opt/lab-stack/reports/phase3-huly-pilot.md`

Do not rotate secrets during rollback unless there is a confirmed exposure.
