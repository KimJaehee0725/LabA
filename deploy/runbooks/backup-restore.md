# Backup And Restore Runbook

## Dry Run

```bash
/srv/lab-platform/scripts/90-backup-all.sh --dry-run
```

## Backup Scope

- Postgres: `authentik`, `plane`, `gitea`, `mlflow`, `nextcloud`, `grist`
- MinIO: `plane-uploads`, `gitea-lfs`, `mlflow-artifacts`
- Gitea dump
- Nextcloud data/config/apps under maintenance mode
- Grist persist/doc files
- Overleaf Mongo and project files

## Restore Drill

Before relying on backups, restore at least one Postgres dump into a temporary DB, mirror one MinIO bucket into a temporary bucket, and list archive contents for Gitea, Nextcloud, Grist, and Overleaf.
