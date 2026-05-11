# Phase 6 Overleaf Runbook

Status: conditional smoke automation passed; strict manual full-pass evidence
pending.

Overleaf CE is deployed as a separate Compose module behind the shared Nginx
edge. It uses manual accounts for Phase 6. Authentik SSO, Server Pro features,
Track Changes, rich project history, and LDAP integration remain out of scope.

Do not record SMTP credentials, generated Redis/session secrets, admin
activation URLs, project Git credentials, private paper content, or raw user
email lists in git, reports, history, screenshots, or shared chat.

## Design Notes

- Compose stays direct rather than adopting the Overleaf Toolkit so it matches
  the existing `/opt/lab-stack` env, Nginx, backup, and check layout.
- The module owns `overleaf`, `overleaf-mongo`, and `overleaf-redis`.
- No host ports are published. Public access is only through Nginx at
  `https://overleaf.lab.example.ac.kr`.
- The shared Docker networks are reused only for Nginx reachability and storage
  isolation: `labstack_backend` and `labstack_data`.
- MongoDB runs as a single-node replica set named `overleaf-rs`.
- Redis uses append-only persistence and password authentication.
- Overleaf 5.x uses `OVERLEAF_*` environment names; Redis compatibility values
  also set `REDIS_HOST`, `REDIS_PORT`, and `REDIS_PASSWORD`.

Reference:

- <https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/environment-variables>
- <https://docs.overleaf.com/on-premises/configuration/overleaf-toolkit/redis>
- <https://docs.overleaf.com/on-premises/maintenance/data-and-backups>

## Prepare Env

On the server, copy the example env and fill server-only values:

```bash
sudo cp /opt/lab-stack/env/70-overleaf.env.example /opt/lab-stack/env/70-overleaf.env
sudo editor /opt/lab-stack/env/70-overleaf.env
```

Required generated values:

```bash
openssl rand -base64 48
```

Set at least:

- `OVERLEAF_SESSION_SECRET`
- `OVERLEAF_REDIS_PASSWORD`
- `OVERLEAF_SMTP_*` values for full pass
- `OVERLEAF_ADMIN_EMAIL`
- `OVERLEAF_SITE_URL=https://$OVERLEAF_DOMAIN`

For conditional smoke without real DNS or real SMTP, keep SMTP placeholders and
run checks with the relaxed flags shown below. This is staging evidence only.
For full pass, remove the relaxed flags and prove real DNS, trusted TLS, and
real SMTP delivery.

## Build And Start

```bash
cd /opt/lab-stack/compose/overleaf
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/70-overleaf.env \
  build

sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/70-overleaf.env \
  up -d
```

Initialize the Mongo replica set:

```bash
sudo /opt/lab-stack/scripts/81-bootstrap-overleaf.sh
```

Reload the shared edge only after Nginx config validates:

```bash
sudo docker exec nginx nginx -t
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  -f /opt/lab-stack/compose/edge/docker-compose.yml \
  up -d --force-recreate nginx
```

## Create Admin

Admin activation output is a secret. Do not paste it into reports or shared
messages.

```bash
set -a
. /opt/lab-stack/env/70-overleaf.env
set +a
sudo docker exec overleaf /bin/bash -lc \
  "cd /overleaf && grunt user:create-admin --email='${OVERLEAF_ADMIN_EMAIL}'"
```

Open the activation URL privately, set a strong password, then delete any shell
scrollback or private note that stored the URL.

## Automated Checks

Conditional smoke check for Overleaf only:

```bash
STAGING_IP=127.0.0.1 \
  PHASE6_REQUIRE_REAL_DOMAINS=false \
  PHASE6_REQUIRE_SMTP=false \
  sudo -E /opt/lab-stack/scripts/80-check-overleaf.sh
```

Integrated conditional smoke check with existing phases:

```bash
STAGING_IP=127.0.0.1 \
  PHASE2_REQUIRE_REAL_DOMAINS=false \
  PHASE2_REQUIRE_SMTP=false \
  PHASE3_REQUIRE_REAL_DOMAINS=false \
  PHASE3_REQUIRE_GITHUB=false \
  PHASE3_REQUIRE_CALENDAR=false \
  PHASE3_REQUIRE_PILOT_FULL_PASS=false \
  PHASE4_REQUIRE_REAL_DOMAINS=false \
  PHASE5_REQUIRE_REAL_DOMAINS=false \
  PHASE6_REQUIRE_REAL_DOMAINS=false \
  PHASE6_REQUIRE_SMTP=false \
  LABSTACK_INCLUDE_HULY=true \
  LABSTACK_INCLUDE_MINIO=true \
  LABSTACK_INCLUDE_HF_UI=true \
  LABSTACK_INCLUDE_OVERLEAF=true \
  sudo -E /opt/lab-stack/scripts/96-check-all.sh
```

These conditional smoke commands deliberately allow staging DNS/TLS and SMTP
placeholders. They are not strict full-pass evidence.

Full pass must remove relaxed flags and use real DNS, trusted TLS, and real
SMTP:

```bash
PHASE6_REQUIRE_SMTP=true sudo -E /opt/lab-stack/scripts/80-check-overleaf.sh
```

`80-check-overleaf.sh` proves container health, Nginx routing, Mongo/Redis,
`latexmk`, `kotex`, and HTTP reachability. In conditional smoke mode it does
not prove browser-trusted TLS because the public probe uses staging-compatible
TLS handling, and it does not prove SMTP delivery beyond placeholder/env
presence. Record separate browser or non-`-k` curl evidence for trusted TLS and
real invite/password mail delivery.

## Manual Browser Smoke

Use a private browser session and a private evidence folder.

| Check | Expected result | Evidence ref | Notes |
| --- | --- | --- | --- |
| Public route | `https://overleaf.lab.example.ac.kr` loads with trusted TLS | | |
| Admin activation | Admin password is set through the private activation URL | 2026-05-11 conditional smoke | Activation URL and password stayed in local `0600` files only |
| Login/logout | Admin login works and logout clears access | | |
| User invite | Invite email is delivered through SMTP | | |
| English compile | A small article compiles to PDF | 2026-05-11 conditional smoke | HTTP session compile returned `success` with `output.pdf` |
| Korean compile | A small `kotex` document compiles to PDF | 2026-05-11 conditional smoke | HTTP session `xelatex` compile returned `success` with `output.pdf` |
| Collaboration | Two browser sessions see edits without WebSocket errors | Partial: 2026-05-11 socket route smoke | `/socket.io/` returned HTTP 200; two-browser edit evidence still pending |
| Git clone | Project Git clone works if enabled for the project | | |

Strict full-pass blockers remain open until all rows above have private evidence
and the runbook has a backup artifact checksum plus restore rehearsal note. Do
not paste activation URLs, passwords, tokens, private project content, SMTP
headers with secrets, or raw private evidence values into this file.

Korean compile sample:

```tex
\documentclass{article}
\usepackage{kotex}
\begin{document}
안녕하세요. Overleaf 한국어 컴파일 확인입니다.
\end{document}
```

The custom image must include `fontspec`, `xetexko`, and `luatexko` in addition
to the base `kotex` packages. Without these packages, XeLaTeX Korean compile
fails after loading `kotex.sty`.

## Backup

Overleaf backups need MongoDB, Redis, and filesystem data. Prefer a maintenance
window where users are not editing projects.

```bash
sudo /opt/lab-stack/scripts/95-backup-overleaf.sh
```

Dry-run:

```bash
DRY_RUN=true sudo -E /opt/lab-stack/scripts/95-backup-overleaf.sh
```

Record only artifact paths and checksums in reports, not paper content.

## Rollback

```bash
cd /opt/lab-stack/compose/overleaf
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/70-overleaf.env \
  down
```

If Nginx routing is the only failing surface, remove or disable
`/opt/lab-stack/nginx/conf.d/70-overleaf.conf`, validate with `nginx -t`, and
recreate only the `nginx` container. Preserve `/opt/lab-stack/data/overleaf`
until backup and restore status is clear.
