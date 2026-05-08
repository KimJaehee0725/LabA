# Change - Enable history recall with numpy

Date: 2026-05-08 10:14 +0000
Agent: codex
Status: completed

## Why

The track-research-history recall command previously could not use BM25 ranking because numpy was missing.

## How

Installed numpy into the Python 3.12 user site using uv with --python /usr/bin/python3 after removing an incompatible CPython 3.11 wheel install.

## Files

-

## Validation

- python3 -c 'import numpy; print(numpy.__version__)' && python3 /home/jaeheekim/.codex/skills/track-research-history/scripts/history.py recall --query 'v0.2 implementation backlog env split git commit branch worktree' --limit 5

## Risks / Follow-Ups

-

## Git Status Snapshot

```text
?? .gitignore
?? docs/
?? history/
?? init_docs/
```
