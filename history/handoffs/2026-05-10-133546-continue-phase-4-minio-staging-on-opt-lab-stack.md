# Handoff - Continue Phase 4 MinIO staging on /opt lab stack

Date: 2026-05-10 13:35 +0000
To: root-capable operator or next agent

Task: 
Workstream: 
## Summary

Repo-side Phase 4 MinIO storage implementation and static validation are complete. Staging execution was blocked by /opt/lab-stack permissions and sudo password requirement.

## Ownership / Files

- deploy/runbooks/phase4-minio-storage.md
- deploy/reports/phase4-minio-storage.md
- deploy/scripts/33-bootstrap-minio-storage.sh
- deploy/scripts/34-check-minio-storage.sh
- deploy/scripts/35-check-minio-backup-smoke.sh

## Next Actions

Copy/sync repo deploy files to /opt/lab-stack, create 35-minio-storage.env with server-only secrets already in 10-core/20-authentik, run 22-bootstrap-authentik-oidc.sh, start core minio profile, then run scripts 33/34/35 and LABSTACK_INCLUDE_MINIO=true 96-check-all.sh.

## Risks

Do not expose MINIO_ROOT_PASSWORD or MINIO_OIDC_CLIENT_SECRET in reports/history. Keep huly-minio separate from shared core minio.
