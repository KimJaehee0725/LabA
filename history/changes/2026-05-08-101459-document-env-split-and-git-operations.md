# Change - Document env split and git operations

Date: 2026-05-08 10:14 +0000
Agent: codex
Status: completed

## Why

v0.2 implementation needs a clear env layout and git workflow before compose and scripts are added.

## How

Added docs/v0.1/12-env-and-git-operations.md, updated v0/v0.1 docs to refer to split env files, and added .gitignore patterns for secret env and TLS key files.

## Files

- .gitignore
- docs/v0.1/12-env-and-git-operations.md
- docs/v0.1/01-core-infrastructure.md
- docs/v0.1/10-v0.2-implementation-backlog.md
- docs/v0/01-infrastructure.md

## Validation

- rg split env docs/v0 docs/v0.1

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
?? .gitignore
?? docs/
?? history/
?? init_docs/
```
