# Change - Add staging demo data seed scripts

Date: 2026-05-08 15:43 +0000
Agent: codex
Status: completed

## Why

교수님 시연용으로 실제 staging Authentik, Gitea, Plane에 비밀 없는 샘플 계정과 콘텐츠가 필요했다.

## How

99-demo.env.example, seed/cleanup 스크립트, demo-data runbook을 추가하고 실제 서버에는 root-owned 99-demo.env를 생성했다. Authentik demo.member를 lab-member에 넣고, Gitea public demo repo 3개를 만들었으며, Plane local demo user/workspace/projects/issues를 생성했다.

## Files

- deploy/env/99-demo.env.example
- deploy/env/README.md
- deploy/scripts/52-seed-demo-data.sh
- deploy/scripts/53-clean-demo-data.sh
- deploy/runbooks/demo-data.md
- deploy/runbooks/README.md

## Validation

- bash -n deploy/scripts/52-seed-demo-data.sh deploy/scripts/53-clean-demo-data.sh
- git diff --check
- runtime: seed script completed; Gitea demo pages returned HTTP 200; Plane local login redirected to https://lab.snu.ac.kr/lab-demo
- runtime: Plane demo workspace `lab-demo` has 2 projects and 6 issues; profile onboarding points to the seeded workspace

## Risks / Follow-Ups

- Plane/Auth generic OIDC remains a v0.3.0 blocker; this demo uses Plane local login intentionally.

## Git Status Snapshot

```text
M deploy/env/README.md
 M deploy/runbooks/README.md
 M history/INDEX.md
?? deploy/env/99-demo.env.example
?? deploy/runbooks/demo-data.md
?? deploy/scripts/52-seed-demo-data.sh
?? deploy/scripts/53-clean-demo-data.sh
```
