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
9. `grist.md`
10. `overleaf.md`
11. `backup-restore.md`
12. `v0.3-smoke.md`
13. `demo-data.md`

Common preflight:

```bash
cd /srv/lab-platform
sudo ./scripts/00-create-directories.sh
sudo ./scripts/01-create-networks.sh
```

After `v0.2-runtime-gate-1.md` passes, keep core, edge, and Authentik running. App waves build on those services.

Rollback rule: stop the affected module first, keep database/object storage intact, preserve logs, and do not rotate or overwrite secrets during incident triage.
