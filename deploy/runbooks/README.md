# Runbook Index

## Active Huly Workspace MVP Runbooks

Run the active Huly workspace MVP phases in this order:

1. `phase1-host-skeleton.md`
2. `phase2-edge-auth.md`
3. `phase3-huly.md`
4. `phase4-minio-storage.md`
5. `phase5-hf-ui.md`
6. `overleaf.md` when Phase 6 Overleaf is enabled
7. `full-pass-readiness.md` and the supporting full-pass checklists
8. Backup/monitoring runbooks to be refreshed before pilot opening

Common Phase 1 dry-run:

```bash
DRY_RUN=true LAB_STACK_ROOT=/opt/lab-stack deploy/scripts/00-create-directories.sh
DRY_RUN=true deploy/scripts/01-create-networks.sh
DRY_RUN=true deploy/scripts/09-check-host-readiness.sh
```

Phase 1 does not start live services and does not create real secrets.

Phase 2 is staging-first and may start only the minimal Edge/Auth surface after
the root, network, domain, certificate, SMTP, and secret preflight passes. Record
staging evidence in `../reports/phase2-edge-auth-staging.md`.

Phase 3 starts Huly after Phase 2 OIDC metadata exists. For staging without real
external credentials, run the Phase 3 preflight with explicit relaxed flags and
record the result in `../reports/phase3-huly-pilot.md`.

Phase 4 starts the shared core MinIO profile, bootstraps lab storage buckets and
policies, checks public/private S3 behavior, and records backup smoke evidence in
`../reports/phase4-minio-storage.md`.

Phase 5 starts the HF-like UI MVP on top of the Phase 4 buckets, validates a
model/dataset catalog, file tree, and download flow, and records evidence in
`../reports/phase5-hf-ui.md`.

Phase 6 starts Overleaf CE as a separate manual-account paper collaboration
module, validates Mongo replica set, Redis auth, LaTeX/Korean package presence,
public edge routing, and records evidence in `../reports/phase6-overleaf.md`.

After Phase 2-5 staging conditional-pass, use the full-pass readiness runbooks
before promoting the environment:

- `full-pass-readiness.md`
- `full-pass-security-edge-auth.md`
- `full-pass-huly-ops.md`
- `full-pass-storage-hf.md`

## Historical v0.x Runbooks

The following runbooks document the archived Plane/Gitea/MLflow/Nextcloud direction and remain reference material only unless a later decision explicitly reactivates them:

- `v0.2-runtime-gate-1.md`
- `core.md`
- `edge-nginx.md` - historical v0.x Nginx reference, not the active Phase 2 procedure
- `authentik.md` - historical v0.x Authentik reference, not the active Phase 2 procedure
- `gitea.md`
- `plane.md`
- `mlflow.md`
- `nextcloud-collabora.md`
- `backup-restore.md`
- `v0.3-smoke.md`
- `demo-data.md`

Rollback rule for any later live phase: stop the affected module first, preserve data and logs, and do not rotate or overwrite secrets during incident triage.
