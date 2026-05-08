# Runbook Index

Run modules in this order:

1. `core.md`
2. `edge-nginx.md`
3. `authentik.md`
4. `gitea.md`
5. `plane.md`
6. `mlflow.md`
7. `nextcloud-collabora.md`
8. `overleaf.md`
9. `backup-restore.md`
10. `v0.3-smoke.md`

Common preflight:

```bash
cd /srv/lab-platform
sudo ./scripts/00-create-directories.sh
sudo ./scripts/01-create-networks.sh
```

Rollback rule: stop the affected module first, keep database/object storage intact, preserve logs, and do not rotate or overwrite secrets during incident triage.
