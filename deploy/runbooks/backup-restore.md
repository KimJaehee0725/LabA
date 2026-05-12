# Backup And Restore Runbook

Status: historical v0.x backup notes plus active Phase 7 entrypoints.

Use `phase7-operational-baseline.md` for the current Huly workspace MVP active
stack. The older service-specific commands below remain reference material for
archived Plane/Gitea/Nextcloud/MLflow work unless their opt-in flags are set.

## Active Stack Dry Run

```bash
DRY_RUN=true sudo -E /opt/lab-stack/scripts/90-backup-all.sh --dry-run
```

## Active Stack Backup Scope

- Postgres: active core/Auth databases.
- Redis: active core Redis RDB.
- Authentik: media/certs/templates archive.
- Shared MinIO/HF storage: Phase 4/5 buckets.
- Huly: cold data archive under a maintenance stop.
- Overleaf: Mongo archive, Redis archive, project files.
- Edge metadata: Nginx config archive plus redacted env/cert metadata.

## Active Restore Drill

Before relying on backups, run:

```bash
sudo -E /opt/lab-stack/scripts/89-restore-rehearsal.sh \
  --backup-root /mnt/backup/lab/archive/phase7/YYYY-MM-DD/YYYYMMDDTHHMMSSZ
```

The rehearsal restores one Postgres dump into a temporary DB, mirrors shared
MinIO backup data into a temporary bucket, lists the Huly cold archive, and runs
Overleaf Mongo `mongorestore --dryRun`.

## Historical Restore Drill

For archived modules, restore at least one Postgres dump into a temporary DB,
mirror one MinIO bucket into a temporary bucket, and list archive contents for
Gitea and Nextcloud before reactivating those services.
