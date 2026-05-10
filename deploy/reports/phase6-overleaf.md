# Phase 6 Overleaf Report

Status: automated staging validation passed with manual browser smoke pending.

## Scope

- Overleaf CE direct Docker Compose module.
- Manual accounts only.
- Shared Nginx route at `https://overleaf.lab.example.ac.kr`.
- Dedicated `overleaf-mongo` and `overleaf-redis`.
- No Authentik SSO or Server Pro-only features.

## Expected Conditional Staging Evidence

| Check | Result | Evidence | Notes |
| --- | --- | --- | --- |
| Compose config renders | Passed | `docker compose --env-file deploy/env/00-global.env.example --env-file deploy/env/70-overleaf.env.example -f deploy/compose/overleaf/docker-compose.yml config` | Local static validation |
| Custom image builds | Passed | `docker compose ... build --no-cache` on staging, 2026-05-10 | Uses `sharelatex/sharelatex:5.5.8` and frozen TeX Live 2025 repository |
| Containers running | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | `overleaf`, `overleaf-mongo`, and `overleaf-redis` running without host ports |
| Mongo replica set initialized | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | `overleaf-rs` initialized |
| Redis auth ping passes | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | Authenticated ping succeeds without printing the password |
| Nginx config passes | Passed | `nginx -t` and `80-check-overleaf.sh`, 2026-05-10T20:22:40Z | Public route is served by shared edge Nginx |
| Public route returns 2xx/3xx | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | Returned HTTP 302 through `127.0.0.1` staging route |
| `latexmk` and `kotex` available | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:40Z | `kpsewhich kotex.sty` succeeds |
| Admin creation completed | Manual pending | | Private activation URL must not be recorded |
| English and Korean sample compile | Manual pending | | Requires browser/admin smoke |

## Staging Automated Validation

- `docker compose --env-file /opt/lab-stack/env/00-global.env --env-file /opt/lab-stack/env/70-overleaf.env build --no-cache`: passed after image/runtime fixes.
- `/opt/lab-stack/scripts/81-bootstrap-overleaf.sh`: passed; Mongo replica set ready.
- `STAGING_IP=127.0.0.1 PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false /opt/lab-stack/scripts/80-check-overleaf.sh`: passed at `2026-05-10T20:22:41Z`.
- `STAGING_IP=127.0.0.1 PHASE2_REQUIRE_REAL_DOMAINS=false PHASE2_REQUIRE_SMTP=false PHASE3_REQUIRE_REAL_DOMAINS=false PHASE3_REQUIRE_GITHUB=false PHASE3_REQUIRE_CALENDAR=false PHASE3_REQUIRE_PILOT_FULL_PASS=false PHASE4_REQUIRE_REAL_DOMAINS=false PHASE5_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false LABSTACK_INCLUDE_HULY=true LABSTACK_INCLUDE_MINIO=true LABSTACK_INCLUDE_HF_UI=true LABSTACK_INCLUDE_OVERLEAF=true /opt/lab-stack/scripts/96-check-all.sh`: passed at `2026-05-10T20:24:42Z`.

## Runtime Fixes Applied During Staging

- Updated the base image from unavailable `sharelatex/sharelatex:5.0.8` to `sharelatex/sharelatex:5.5.8`.
- Quoted `OVERLEAF_APP_NAME` and `OVERLEAF_NAV_TITLE` in the env example so shell-loaded values with spaces remain valid.
- Removed duplicate Overleaf Nginx proxy timeout directives because `upload-large.conf` already owns those settings.
- Pinned `tlmgr` to the final TeX Live 2025 repository and removed the unavailable `hcr-lvt` package so Korean package installation is reproducible.
- Added Overleaf data ownership correction in `00-create-directories.sh`; the Overleaf web process runs as `www-data` and needs traversal/write access to `/var/lib/overleaf`.

## Local Static Validation

- `bash -n deploy/scripts/00-create-directories.sh deploy/scripts/80-check-overleaf.sh deploy/scripts/81-bootstrap-overleaf.sh deploy/scripts/95-backup-overleaf.sh deploy/scripts/96-check-all.sh`: passed.
- Overleaf Compose config with example env files: passed.
- Edge Compose config with example global env: passed.
- `DRY_RUN=true ... 81-bootstrap-overleaf.sh --dry-run`: passed.
- `DRY_RUN=true ... 95-backup-overleaf.sh --dry-run`: passed.
- `git diff --check`: passed.

## Full-Pass Blockers

- Real DNS and trusted TLS for `OVERLEAF_DOMAIN`.
- Real SMTP delivery for admin/user invite and password flows.
- Browser evidence for admin activation, user invite, compile, collaboration,
  and logout.
- Backup artifact checksum and restore rehearsal note.
