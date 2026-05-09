# Runbook Index

## Active Huly Workspace MVP Runbooks

Run the active Huly workspace MVP phases in this order:

1. `phase1-host-skeleton.md`
2. Edge/Auth runbook to be written in Phase 2
3. Huly pilot runbook to be written in Phase 3
4. Storage/HF UI runbooks to be written in later phases
5. Overleaf runbook refresh to be written before Overleaf CE deployment
6. Backup/monitoring runbooks to be refreshed before pilot opening

Common Phase 1 dry-run:

```bash
DRY_RUN=true LAB_STACK_ROOT=/opt/lab-stack deploy/scripts/00-create-directories.sh
DRY_RUN=true deploy/scripts/01-create-networks.sh
DRY_RUN=true deploy/scripts/09-check-host-readiness.sh
```

Phase 1 does not start live services and does not create real secrets.

## Historical v0.x Runbooks

The following runbooks document the archived Plane/Gitea/MLflow/Nextcloud direction and remain reference material only unless a later decision explicitly reactivates them:

- `v0.2-runtime-gate-1.md`
- `core.md`
- `edge-nginx.md`
- `authentik.md`
- `gitea.md`
- `plane.md`
- `mlflow.md`
- `nextcloud-collabora.md`
- `overleaf.md`
- `backup-restore.md`
- `v0.3-smoke.md`
- `demo-data.md`

Rollback rule for any later live phase: stop the affected module first, preserve data and logs, and do not rotate or overwrite secrets during incident triage.
