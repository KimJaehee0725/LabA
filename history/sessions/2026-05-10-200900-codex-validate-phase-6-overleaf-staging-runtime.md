# Session - Validate Phase 6 Overleaf staging runtime

Date: 2026-05-10 20:09 +0000
Agent: codex

## Scope

Sync huly/overleaf-mvp to /opt/lab-stack, build/start Overleaf, run conditional automated checks, push branch and open draft PR

## Read First

- `deploy/reports/phase6-overleaf.md`
- `deploy/compose/overleaf/Dockerfile`
- `deploy/scripts/00-create-directories.sh`

## Plan

- Sync the Overleaf branch artifacts to `/opt/lab-stack`.
- Build the custom Overleaf image, initialize Mongo replica set, and start Redis/Overleaf/Nginx.
- Run Phase 6 automated checks, then conditional `96-check-all.sh`.
- Record staging fixes and validation, commit, push, and open a draft PR.

## Work Log

- Synced the Overleaf compose, env example, Nginx route, scripts, runbook, and report into `/opt/lab-stack`.
- Replaced unavailable `sharelatex/sharelatex:5.0.8` with `sharelatex/sharelatex:5.5.8`.
- Fixed shell-loaded env values with spaces by quoting `OVERLEAF_APP_NAME` and `OVERLEAF_NAV_TITLE`.
- Removed duplicate `proxy_read_timeout` and `proxy_send_timeout` directives from `70-overleaf.conf`; the shared upload snippet already defines them.
- Pinned `tlmgr` to the final TeX Live 2025 repository, added `tlmgr update --self`, and removed the unavailable `hcr-lvt` package.
- Added Overleaf data ownership correction in `00-create-directories.sh` so the `www-data` web process can create `/var/lib/overleaf/tmp/uploads`.
- Ran `/opt/lab-stack/scripts/80-check-overleaf.sh` successfully with staging domain/SMTP relaxations.
- Ran `/opt/lab-stack/scripts/96-check-all.sh` with Huly, MinIO, HF UI, and Overleaf enabled. The first full run stopped on the existing Phase 3 pilot full-pass requirement, then passed with `PHASE3_REQUIRE_PILOT_FULL_PASS=false` because the user had not completed that manual full pass yet.

## End Summary

- Automated Phase 6 Overleaf staging validation is complete.
- Remaining work is manual browser smoke: admin activation, English/Korean compile, collaboration/logout evidence, plus real DNS/TLS/SMTP for production-like full pass.
- Publish flow still needs local static verification, commit, push, and draft PR creation.
