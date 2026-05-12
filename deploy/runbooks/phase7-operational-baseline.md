# Phase 7 Internal Operational Baseline Runbook

Status: internal operational baseline passed; strict full-pass evidence pending.

Phase 7 closes the parts of operations readiness that do not require new
external information. It does not replace strict full-pass. Real DNS, trusted
TLS, real SMTP, credential rotation, browser OIDC evidence, GitHub/Google
credentials, and the one-week pilot remain separate full-pass blockers.

## Baseline Definition

Internal operational baseline means:

- Active services are running behind Nginx with no direct host ports.
- Active backup artifacts exist for core/Auth, shared MinIO/HF storage, Huly,
  Overleaf, and edge metadata.
- A non-destructive or isolated restore rehearsal has passed.
- Disk usage, certificate expiry, env/cert permissions, and repo-facing secret
  scans are checked.
- Strict external blockers are logged as warnings, not represented as pass.

## Active Backup

Dry-run first:

```bash
DRY_RUN=true sudo -E /opt/lab-stack/scripts/90-backup-all.sh --dry-run
```

Actual backup:

```bash
PHASE7_ALLOW_HULY_STOP=true \
  sudo -E /opt/lab-stack/scripts/90-backup-all.sh
```

`PHASE7_ALLOW_HULY_STOP=true` is required because Huly backup is a cold archive.
Run it only during a maintenance window. To skip Huly during a rehearsal, set
`LABSTACK_BACKUP_HULY=false` and record that Huly restore evidence is pending.

The script writes to:

```text
/mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ/
```

Every run must include `manifest.tsv`. Record only artifact paths, sizes,
checksums, and timestamps. Do not paste env values, passwords, tokens, private
keys, activation URLs, or session cookies into reports.

## Restore Rehearsal

Dry-run:

```bash
DRY_RUN=true sudo -E /opt/lab-stack/scripts/89-restore-rehearsal.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

Actual isolated rehearsal:

```bash
sudo -E /opt/lab-stack/scripts/89-restore-rehearsal.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

The rehearsal performs:

- Postgres restore into a temporary database, then drops it.
- MinIO extraction and temporary-bucket mirror, then removes the bucket.
- Huly cold archive listing.
- Overleaf Mongo `mongorestore --dryRun`.

The script writes `restore-rehearsal.tsv` next to the backup manifest.

Current evidence root:

```text
/mnt/backup/lab/archive/phase7/2026-05-12/20260512T054224Z
```

## Ops Baseline Gate

Run after backup and restore rehearsal:

```bash
LABSTACK_INCLUDE_HULY=true \
LABSTACK_INCLUDE_MINIO=true \
LABSTACK_INCLUDE_HF_UI=true \
LABSTACK_INCLUDE_OVERLEAF=true \
  sudo -E /opt/lab-stack/scripts/99-check-ops-baseline.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

Optional integrated check:

```bash
LABSTACK_INCLUDE_HULY=true \
LABSTACK_INCLUDE_MINIO=true \
LABSTACK_INCLUDE_HF_UI=true \
LABSTACK_INCLUDE_OVERLEAF=true \
LABSTACK_INCLUDE_OPS_BASELINE=true \
  sudo -E /opt/lab-stack/scripts/96-check-all.sh
```

For staging/internal evidence, keep the existing relaxed phase flags where they
are still required. A run that uses relaxed flags remains internal baseline
evidence, not strict full-pass evidence.

## Evidence Template

```text
Phase 7 internal operational baseline:
- Backup root:
- Manifest: present / missing
- Restore rehearsal: pass / fail
- Ops baseline script: pass / fail
- Disk usage: pass / warn / fail
- Certificate expiry: pass / warn / fail
- Secret scan: pass / fail
- Strict full-pass blockers still open:
- Evidence files stored outside git:
```

## Stop Criteria

- A script prints or records real secret values.
- Huly cannot restart after a cold backup.
- Restore rehearsal leaves a temporary database or bucket behind.
- Backup artifacts are empty or missing from `manifest.tsv`.
- Any direct host port is exposed by a non-Nginx active service.
- Disk or certificate checks cross the configured fail thresholds.
