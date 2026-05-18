# Change - Tighten Overleaf Korean TeX smoke check

Date: 2026-05-11 09:04 +0000
Agent: codex
Status: completed

## Why

Korean compile initially failed because xetexko and fontspec were absent even though kotex.sty existed.

## How

Added fontspec, xetexko, and luatexko to the image package list and extended 80-check-overleaf.sh to verify those files with kpsewhich.

## Files

- deploy/compose/overleaf/Dockerfile
- deploy/scripts/80-check-overleaf.sh

## Validation

- Korean xelatex compile returned success with output.pdf

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
M deploy/compose/overleaf/Dockerfile
 M deploy/reports/phase6-overleaf.md
 M deploy/runbooks/full-pass-readiness.md
 M deploy/runbooks/overleaf.md
 M deploy/scripts/80-check-overleaf.sh
 M history/INDEX.md
 M history/daily/2026-05-11.md
?? history/changes/2026-05-11-090418-record-overleaf-conditional-smoke-evidence.md
?? history/experiments/0017-complete-overleaf-conditional-smoke.md
```
