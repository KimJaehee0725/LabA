# Change - Add full-pass readiness runbooks

Date: 2026-05-10 19:45 +0000
Agent: codex
Status: completed

## Why

Phase 2-5는 staging conditional-pass 상태라 real DNS/TLS/SMTP, browser OIDC evidence, credential rotation, role evidence를 닫기 전에는 full-pass로 승격할 수 없다.

## How

Sub-agent별로 Edge/Auth security, Huly/Ops, Storage/HF full-pass checklist를 작성하고 coordinator overview와 runbook index를 추가했다.

## Files

- deploy/runbooks/full-pass-readiness.md
- deploy/runbooks/full-pass-security-edge-auth.md
- deploy/runbooks/full-pass-huly-ops.md
- deploy/runbooks/full-pass-storage-hf.md
- deploy/runbooks/README.md

## Validation

- git diff --check
- secret scan for token/private-key/generated secret patterns
- bash -n deploy/scripts/19-check-phase2-preflight.sh deploy/scripts/23-check-phase3-huly-preflight.sh deploy/scripts/34-check-minio-storage.sh deploy/scripts/44-check-hf-ui.sh deploy/scripts/96-check-all.sh

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/runbooks/README.md
 M history/INDEX.md
 M history/daily/2026-05-10.md
?? deploy/runbooks/full-pass-huly-ops.md
?? deploy/runbooks/full-pass-readiness.md
?? deploy/runbooks/full-pass-security-edge-auth.md
?? deploy/runbooks/full-pass-storage-hf.md
?? history/sessions/2026-05-10-194157-codex-implement-full-pass-readiness-sub-agent-wave.md
```
