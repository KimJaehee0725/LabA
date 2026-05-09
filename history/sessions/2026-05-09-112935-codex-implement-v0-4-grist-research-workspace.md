# Session - Implement v0.4 Grist research workspace

Date: 2026-05-09 11:29 +0000
Agent: codex

## Scope

Grist compose/env/bootstrap/seed/check/docs/data model

## Read First

-

## Plan

- Add Grist service wiring for compose, env, Nginx, directories, Postgres, and Authentik OIDC.
- Add v0.4 domain catalog plus Grist research hub seed/check scripts.
- Extend Plane/Nextcloud demo seed scripts to use `LAB_DOMAIN_CATALOG_VERSION`.
- Update backup, integrated smoke, docs, runbooks, and validation report.

## Work Log

- Confirmed upstream/runtime detail: Grist release label is `v1.7.13`, but the Docker image tag used by Docker is `gristlabs/grist-oss:1.7.13`.
- Confirmed Grist bootstrap API auth uses `X-Boot-Key`, not `Authorization: Bearer`.
- Validated Grist seed script against a disposable local Grist container; it created `Lab Research Hub` and was idempotent on a second run.
- Ran static validation, Grist compose render, and backup dry-run with grist DB/persist entries.

## End Summary

- Implemented the v0.4 strict-OSS research workspace repository changes.
- Remaining runtime work requires staging host env secrets and external OIDC/Nginx checks.
