# Phase 6 Overleaf Report

Status: implementation prepared; staging runtime validation pending.

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
| Custom image builds | Pending | | |
| Containers running | Pending | | |
| Mongo replica set initialized | Pending | | |
| Redis auth ping passes | Pending | | |
| Nginx config passes | Pending | | |
| Public route returns 2xx/3xx | Pending | | |
| `latexmk` and `kotex` available | Pending | | |
| Admin creation completed | Pending | Private activation URL not recorded |
| English and Korean sample compile | Pending | | |

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
