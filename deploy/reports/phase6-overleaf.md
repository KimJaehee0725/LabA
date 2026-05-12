# Phase 6 Overleaf Report

Status: conditional smoke automation passed with strict full-pass evidence
pending.

## Scope

- Overleaf CE direct Docker Compose module.
- Manual accounts only.
- Shared Nginx route at `https://overleaf.lab.example.ac.kr`.
- Dedicated `overleaf-mongo` and `overleaf-redis`.
- No Authentik SSO or Server Pro-only features.

## Expected Conditional Smoke Evidence

| Check | Result | Evidence | Notes |
| --- | --- | --- | --- |
| Compose config renders | Passed | `docker compose --env-file deploy/env/00-global.env.example --env-file deploy/env/70-overleaf.env.example -f deploy/compose/overleaf/docker-compose.yml config` | Local static validation |
| Custom image builds | Passed | `docker compose ... build --no-cache` on staging, 2026-05-10 | Uses `sharelatex/sharelatex:5.5.8` and frozen TeX Live 2025 repository |
| Containers running | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | `overleaf`, `overleaf-mongo`, and `overleaf-redis` running without host ports |
| Mongo replica set initialized | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | `overleaf-rs` initialized |
| Redis auth ping passes | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | Authenticated ping succeeds without printing the password |
| Nginx config passes | Passed | `nginx -t` and `80-check-overleaf.sh`, 2026-05-10T20:22:40Z | Public route is served by shared edge Nginx |
| Public route returns 2xx/3xx | Passed | `80-check-overleaf.sh`, 2026-05-10T20:22:41Z | Returned HTTP 302 through `127.0.0.1` staging route |
| `latexmk` and Korean TeX packages available | Passed | `80-check-overleaf.sh`, 2026-05-11 conditional smoke | `kpsewhich` succeeds for `kotex`, `fontspec`, `xetexko`, and `luatexko` |
| Admin creation completed | Passed conditionally | 2026-05-11 conditional smoke | Run from `/overleaf`; private activation URL was not recorded |
| English and Korean sample compile | Passed conditionally | 2026-05-11 conditional smoke | HTTP session compile returned `success` with `output.pdf` |

## Conditional Smoke Validation

- `docker compose --env-file /opt/lab-stack/env/00-global.env --env-file /opt/lab-stack/env/70-overleaf.env build --no-cache`: passed after image/runtime fixes.
- `/opt/lab-stack/scripts/81-bootstrap-overleaf.sh`: passed; Mongo replica set ready.
- `STAGING_IP=127.0.0.1 PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false /opt/lab-stack/scripts/80-check-overleaf.sh`: passed at `2026-05-10T20:22:41Z`.
- `STAGING_IP=127.0.0.1 PHASE2_REQUIRE_REAL_DOMAINS=false PHASE2_REQUIRE_SMTP=false PHASE3_REQUIRE_REAL_DOMAINS=false PHASE3_REQUIRE_GITHUB=false PHASE3_REQUIRE_CALENDAR=false PHASE3_REQUIRE_PILOT_FULL_PASS=false PHASE4_REQUIRE_REAL_DOMAINS=false PHASE5_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false LABSTACK_INCLUDE_HULY=true LABSTACK_INCLUDE_MINIO=true LABSTACK_INCLUDE_HF_UI=true LABSTACK_INCLUDE_OVERLEAF=true /opt/lab-stack/scripts/96-check-all.sh`: passed at `2026-05-10T20:24:42Z`.
- Revalidated on `2026-05-11`: `STAGING_IP=127.0.0.1 PHASE6_REQUIRE_REAL_DOMAINS=false PHASE6_REQUIRE_SMTP=false /opt/lab-stack/scripts/80-check-overleaf.sh` passed at `2026-05-11T07:27:53Z`.
- Revalidated on `2026-05-11`: the relaxed integrated `96-check-all.sh` with Huly, MinIO, HF UI, and Overleaf enabled passed through Overleaf at `2026-05-11T07:28:44Z`.
- Conditional admin smoke on `2026-05-11`: admin account was created through
  `cd /overleaf && grunt user:create-admin`, activated privately, and Mongo now
  has `users=1`, `admins=1`.
- Conditional compile smoke on `2026-05-11`: created one English project and one
  Korean `kotex` project; `pdflatex` and `xelatex` compile requests both
  returned `success` with `output.pdf`.
- Conditional collaboration route smoke on `2026-05-11`: Nginx-served
  `/socket.io/` polling route returned HTTP 200. Two-browser live edit evidence
  remains a strict full-pass item.
- Conditional backup smoke on `2026-05-11`: `/opt/lab-stack/scripts/95-backup-overleaf.sh`
  wrote artifacts under `/mnt/backup/lab/archive/overleaf/2026-05-11`; Mongo
  archive dry-run and file/Redis tar listings succeeded. Checksums:
  `c64213a621944e088236390ea41b78c9e84ab2eec04401dc3cd027d86a86345f`
  for `mongo/overleaf.archive`,
  `6c00900153f8441c51d51ea5756195625afeeb0535bd9d63a348f3f0ca132bb4`
  for `files/overleaf-files.tar.gz`, and
  `b994502506b9b0a464f4f5340fe33cf57f839aa245dde18f4d6627f4911f6d97`
  for `redis/overleaf-redis.tar.gz`.
- Revalidated after the Korean TeX dependency check was added on `2026-05-11`:
  relaxed `80-check-overleaf.sh` passed at `2026-05-11T09:05:24Z`, and the
  relaxed integrated `96-check-all.sh` with Huly, MinIO, HF UI, and Overleaf
  enabled passed through Overleaf at `2026-05-11T09:05:55Z`.
- Phase 7 restore evidence on `2026-05-12`: Overleaf Mongo archive
  `overleaf/mongo/overleaf.archive` under
  `/mnt/backup/lab/archive/phase7/2026-05-12/20260512T054224Z` passed
  `mongorestore --dryRun`; Overleaf file and Redis archives were listed in the
  Phase 7 manifest.

These runs are conditional smoke evidence. They intentionally use relaxed
real-domain and SMTP gates for staging and must not be treated as operational
full-pass evidence.

## Strict Validation Caveats

- `80-check-overleaf.sh` confirms runtime health and route reachability, but it
  does not by itself prove browser-trusted TLS or SMTP delivery.
- Full pass requires separate evidence for real DNS, trusted TLS without a
  staging resolver override, admin activation, invite/password mail delivery,
  English/Korean compile, collaboration/logout, and backup restore rehearsal.
- Admin creation must use the Overleaf application path `/overleaf`, and any
  activation output remains private evidence only.
- PR #2 remains draft while exposed credential rotation is deferred and full-pass
  browser evidence is incomplete.

## Runtime Fixes Applied During Staging

- Updated the base image from unavailable `sharelatex/sharelatex:5.0.8` to `sharelatex/sharelatex:5.5.8`.
- Quoted `OVERLEAF_APP_NAME` and `OVERLEAF_NAV_TITLE` in the env example so shell-loaded values with spaces remain valid.
- Removed duplicate Overleaf Nginx proxy timeout directives because `upload-large.conf` already owns those settings.
- Pinned `tlmgr` to the final TeX Live 2025 repository and removed the unavailable `hcr-lvt` package so Korean package installation is reproducible.
- Added Overleaf data ownership correction in `00-create-directories.sh`; the Overleaf web process runs as `www-data` and needs traversal/write access to `/var/lib/overleaf`.
- Added `fontspec`, `xetexko`, and `luatexko` to the custom image package list
  after the conditional Korean compile exposed missing XeLaTeX Korean
  dependencies.

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
- Browser evidence for login/logout, user invite, trusted TLS, real SMTP
  delivery, and two-session live collaboration.
- Browser evidence remains pending; isolated restore rehearsal is now covered
  by Phase 7 evidence.
- No secrets, activation URLs, passwords, tokens, private paper content, or raw
  private evidence values may be recorded in the report.
