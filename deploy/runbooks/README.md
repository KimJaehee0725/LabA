# Runbook Index

Run modules in this order:

1. `v0.2-runtime-gate-1.md`
2. `core.md`
3. `edge-nginx.md`
4. `authentik.md`
5. `gitea.md`
6. `plane.md`
7. `mlflow.md`
8. `nextcloud-collabora.md`
9. `overleaf.md`
10. `backup-restore.md`
11. `v0.3-smoke.md`

Common preflight:

```bash
cd /srv/lab-platform
sudo ./scripts/00-create-directories.sh
sudo ./scripts/01-create-networks.sh
```

Rollback rule: stop the affected module first, keep database/object storage intact, preserve logs, and do not rotate or overwrite secrets during incident triage.
