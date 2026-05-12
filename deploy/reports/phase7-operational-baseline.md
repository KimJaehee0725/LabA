# Phase 7 Internal Operational Baseline Report

Status: internal operational baseline passed; strict full-pass pending.

## Scope

Phase 7 targets the operational checks that can be completed without new
external information. It covers active-stack backup orchestration, isolated
restore rehearsal, disk/cert/permission checks, active service exposure checks,
and repo-facing secret scan hygiene.

This report does not claim strict full-pass. Real DNS, trusted TLS, real SMTP,
credential rotation or waiver, browser OIDC evidence, external GitHub/Google
integrations, and one-week pilot evidence remain pending.

## Implemented Automation

| Check | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Active backup orchestration | Implemented | `90-backup-all.sh` | Writes Phase 7 backup root and `manifest.tsv` |
| Huly cold archive guard | Implemented | `90-backup-all.sh` | Requires `PHASE7_ALLOW_HULY_STOP=true` |
| Restore rehearsal | Implemented | `89-restore-rehearsal.sh` | Temporary Postgres DB, temporary MinIO bucket, Huly archive listing, Overleaf `mongorestore --dryRun` |
| Ops baseline gate | Implemented | `99-check-ops-baseline.sh` | Containers, ports, disk, cert expiry, permissions, backup/restore evidence, secret scan |
| Integrated opt-in | Implemented | `96-check-all.sh` | `LABSTACK_INCLUDE_OPS_BASELINE=true` adds Phase 7 gate |

## Runtime Evidence

Collected on `2026-05-12` against `/opt/lab-stack`.

| Check | Result | Evidence | Notes |
| --- | --- | --- | --- |
| Active backup | Passed | `/mnt/backup/lab/archive/phase7/2026-05-12/20260512T054224Z/manifest.tsv` | Huly cold archive used a maintenance stop and restart |
| Restore rehearsal | Passed | `/mnt/backup/lab/archive/phase7/2026-05-12/20260512T054224Z/restore-rehearsal.tsv` | Postgres temp DB, MinIO temp bucket, Huly archive listing, Overleaf `mongorestore --dryRun` |
| Ops baseline gate | Passed | `99-check-ops-baseline.sh`, 2026-05-12T05:43:43Z | Passed with 12 warnings for strict external blockers/placeholders |
| Integrated relaxed gate | Passed | `96-check-all.sh`, 2026-05-12T05:54:25Z | Huly, MinIO, HF UI, Overleaf, and Phase 7 ops baseline enabled |
| Huly post-backup runtime | Passed | `30-check-huly.sh`, 2026-05-12T05:44:46Z | Huly containers restarted and route checks passed |
| Overleaf runtime | Passed | `80-check-overleaf.sh`, 2026-05-12T05:44:47Z | Overleaf route and TeX dependency checks still pass |

Backup manifest entries:

| Artifact | Size bytes | SHA256 |
| --- | ---: | --- |
| `postgres/authentik.dump` | 1703512 | `88117af87b6509e1e8f314abf8d338d7180646e6e4638e49c29d0d304ff0566a` |
| `postgres/postgres.dump` | 1084 | `35c6abd1081b34396d1a0538fc36a7dbe1ee477638e19e59eed4edd32ad95530` |
| `redis/core-redis.rdb` | 260643 | `1b8959b6f20d906f0d2eba6554d35393c91dfa40a0b5c6a6347de631f3c6f3cd` |
| `authentik/authentik-data.tar.gz` | 199 | `00906219795524007d4c56d953e362ec68919d1e749ac559f56048773d73f5f2` |
| `edge/metadata.txt` | 1931 | `cb3150d9c3b7d7758db1d1f55c7f2be0beb7c8f122c6326835ccc097d7c028af` |
| `edge/nginx-config.tar.gz` | 3036 | `8b58bb366168ee0cab02714b42b3546c6fc322de9cee4d45a06e5f0a3f0c2a6c` |
| `minio/shared-minio-buckets.tar.gz` | 3388 | `3669f694bda59b22548404808ebe5534633586743d06088ae1d443c41a799d9f` |
| `huly/huly-data-cold.tar.gz` | 156830862 | `5d42afa4c680ba28999ffe568f0bd556a66a419f65a3c0159ccd682c367db97c` |
| `overleaf/mongo/overleaf.archive` | 44254 | `9447b229b4059a49ac4e895837b4e9dc6b41f72e2401350351039eb34f209252` |
| `overleaf/files/overleaf-files.tar.gz` | 129772 | `f979f5782a91ea35ee01334d52615efdaba6758017082bb6bdb6bac86d41e193` |
| `overleaf/redis/overleaf-redis.tar.gz` | 12410 | `5b444825c3b797f172918397ca018862b9c1a4e91664159fa56bc544b87c71f7` |
| `manifest.tsv` | 1750 | `82ce66b03b5660dfabd7e55680536d4707635b4bd04d49f6cdb737d7c669f241` |

Restore rehearsal results:

| Check | Result | Notes |
| --- | --- | --- |
| Postgres | Passed | Temporary DB restore succeeded |
| MinIO | Passed | Temporary bucket mirror succeeded and was removed |
| Huly | Passed | Cold archive listing succeeded |
| Overleaf | Passed | `mongorestore --dryRun` succeeded |

## Strict Full-Pass Blockers

- Exposed credential rotation or an explicit scoped waiver remains required.
- Real DNS and trusted TLS are still required for strict mode.
- Real SMTP delivery and browser invite/password evidence are still required.
- Browser OIDC evidence remains required for Authentik, Huly, MinIO, and HF UI.
- Overleaf browser login/logout, invite mail, and two-browser collaboration
  evidence remain required.
- Huly GitHub App, Google Calendar, Notion/timeline, and one-week pilot evidence
  remain required unless explicitly deferred.
- A pre-existing host process `/workspace/LLM-API-Watcher` (`node dist/index.js`)
  initially listened on public port `3000`, so `10-check-edge.sh` correctly
  stopped on the public-port policy. It was moved to port `3010`, after which
  the relaxed integrated `96-check-all.sh` with Phase 7 opt-in passed on
  `2026-05-12T05:54:25Z`.

## Local Static Validation

- `git diff --check`: passed.
- `bash -n deploy/scripts/*.sh deploy/scripts/lib/common.sh`: passed.
- Active compose config renders for core, edge, Authentik, Huly, MinIO, HF UI,
  and Overleaf: passed.
- `DRY_RUN=true /opt/lab-stack/scripts/90-backup-all.sh --dry-run`: passed.
- `DRY_RUN=true /opt/lab-stack/scripts/89-restore-rehearsal.sh --dry-run --backup-root /tmp/example-phase7-backup`: passed.
- `DRY_RUN=true PHASE7_REQUIRE_BACKUP_EVIDENCE=false /opt/lab-stack/scripts/99-check-ops-baseline.sh --dry-run`: passed.
