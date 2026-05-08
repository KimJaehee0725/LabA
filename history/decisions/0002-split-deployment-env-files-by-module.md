# Decision 0002 - Split deployment env files by module

Date: 2026-05-08 10:14 +0000
Status: accepted

## Context

The user asked to avoid one oversized env file as the platform grows across core, Authentik, Gitea, Plane, MLflow, Nextcloud, Overleaf, MinIO policies, and backup.

## Decision

Use /srv/lab-platform/env/*.env split by global, core, service, MinIO policy, and backup scopes; keep only *.env.example in git.

## Rationale

This reduces secret rotation blast radius, keeps compose inputs understandable, and avoids a single fragile mega-env file.

## Consequences

-
