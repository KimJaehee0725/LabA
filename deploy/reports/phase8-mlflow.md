# Phase 8 MLflow Tracking MVP Report

Status: internal staging validation passed; strict public UI full-pass pending.

## Scope

Phase 8 reactivates MLflow as an active-stack tracking service for the Huly
workspace MVP. It uses shared Postgres for metadata and shared MinIO
`lab-artifacts/mlflow` for artifacts.

This report does not claim public browser SSO or strict full-pass. The MLflow
public route is tracked as a disabled Authentik-gated Nginx template until the
outpost/forward-auth configuration is available and tested.

## Implemented Automation

| Check | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Active compose modernization | Implemented | `compose/mlflow/docker-compose.yml` | Uses `labstack_backend` and `labstack_data`; no host ports |
| Bootstrap | Implemented | `61-bootstrap-mlflow.sh` | Creates Postgres DB/user and MinIO service policy/user |
| Internal runtime check | Implemented | `60-check-mlflow.sh` | Container, no host ports, DB, HTTP, MLflow smoke run, MinIO artifact evidence |
| Integrated opt-in | Implemented | `96-check-all.sh` | `LABSTACK_INCLUDE_MLFLOW=true` adds Phase 8 check |
| Backup/restore opt-in | Implemented | `90-backup-all.sh`, `89-restore-rehearsal.sh` | `LABSTACK_BACKUP_MLFLOW=true` adds DB dump and artifact archive |
| Ops baseline opt-in | Implemented | `99-check-ops-baseline.sh` | Checks MLflow container/no host ports when included |

## Runtime Evidence

Collected on `2026-05-15` against `/opt/lab-stack`.

| Check | Result | Evidence | Notes |
| --- | --- | --- | --- |
| Bootstrap | Passed | `61-bootstrap-mlflow.sh`, 2026-05-15T05:31:30Z | Created/updated MLflow DB, MinIO policy, and service user |
| MLflow build/start | Passed | `docker compose build/up`, 2026-05-15T05:31:40Z | `mlflow` container started with no host ports |
| Internal MLflow check | Passed | `60-check-mlflow.sh`, 2026-05-15T05:37:51Z | Experiment/run/artifact smoke passed; artifact found in `lab-artifacts/mlflow` |
| Integrated relaxed gate | Passed | `96-check-all.sh`, 2026-05-15T05:34:37Z | Huly, MinIO, HF UI, Overleaf, MLflow, and ops baseline enabled with relaxed staging flags |
| Backup with MLflow | Passed | `/mnt/backup/lab/archive/phase7/2026-05-15/20260515T053501Z/manifest.tsv` | Includes MLflow Postgres dump and artifact archive |
| Restore rehearsal with MLflow | Passed | `/mnt/backup/lab/archive/phase7/2026-05-15/20260515T053501Z/restore-rehearsal.tsv` | MLflow temp DB restore and artifact archive listing passed |
| Post-backup Huly runtime | Passed | `30-check-huly.sh`, 2026-05-15T05:36:57Z | Huly recovered after cold backup restart |
| Post-backup Overleaf runtime | Passed | `80-check-overleaf.sh`, 2026-05-15T05:36:58Z | Overleaf remained healthy |

Evidence commands:

```bash
sudo -E /opt/lab-stack/scripts/61-bootstrap-mlflow.sh

PHASE8_REQUIRE_AUTH_GATE=false \
  sudo -E /opt/lab-stack/scripts/60-check-mlflow.sh

LABSTACK_INCLUDE_MLFLOW=true \
PHASE8_REQUIRE_AUTH_GATE=false \
  sudo -E /opt/lab-stack/scripts/96-check-all.sh

LABSTACK_BACKUP_MLFLOW=true \
PHASE7_ALLOW_HULY_STOP=true \
  sudo -E /opt/lab-stack/scripts/90-backup-all.sh

LABSTACK_BACKUP_MLFLOW=true \
  sudo -E /opt/lab-stack/scripts/89-restore-rehearsal.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

## Strict Full-Pass Blockers

- Authentik MLflow proxy/outpost token and route enablement remain pending.
- Public unauthenticated MLflow access must return `302`, `401`, or `403`
  before public UI can be claimed.
- Real DNS, trusted TLS, browser SSO evidence, and credential rotation/waiver
  remain part of the broader full-pass gate.

## Local Static Validation

- `git diff --check`: passed.
- `bash -n deploy/scripts/*.sh deploy/scripts/lib/common.sh`: passed.
- MLflow compose config render with example env: passed.
- High-risk repo-facing secret pattern scan across `deploy`, `docs`, and
  `history`: passed.
