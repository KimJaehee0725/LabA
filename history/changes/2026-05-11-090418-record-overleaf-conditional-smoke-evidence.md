# Change - Record Overleaf conditional smoke evidence

Date: 2026-05-11 09:04 +0000
Agent: codex
Status: completed

## Why

Phase 6 needed admin, compile, socket, and backup evidence before leaving conditional smoke pending state.

## How

Updated Overleaf reports/runbooks, added XeLaTeX Korean dependencies to the custom image package list, and recorded remaining strict full-pass blockers.

## Files

- deploy/compose/overleaf/Dockerfile
- deploy/reports/phase6-overleaf.md
- deploy/runbooks/overleaf.md
- deploy/runbooks/full-pass-readiness.md

## Validation

- English/Korean compile smoke, socket route smoke, backup checksum/listing, and Phase 6 check

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/overleaf/Dockerfile
 M deploy/reports/phase6-overleaf.md
 M deploy/runbooks/full-pass-readiness.md
 M deploy/runbooks/overleaf.md
 M history/INDEX.md
 M history/daily/2026-05-11.md
?? history/experiments/0017-complete-overleaf-conditional-smoke.md
```
