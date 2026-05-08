# Decision 0003 - Use commits and branches at module checkpoints

Date: 2026-05-08 10:14 +0000
Status: accepted

## Context

The user asked Codex to commit, branch out, create worktrees, and merge at appropriate timings during the platform build.

## Decision

Commit at completed planning or module validation checkpoints; create feature branches for substantial v0.2 modules; use worktrees only for parallel module work or smoke fixes.

## Rationale

This keeps the large platform build recoverable without overusing worktrees before there is meaningful parallel implementation.

## Consequences

-
