# Lab Platform Deploy

This directory contains the deployment implementation files for the lab self-hosted platform.

The default server root is `/srv/lab-platform`. Repository files are intended to be copied or synced into that root, with real environment files created from `deploy/env/*.env.example` and stored outside git.

## Layout

```text
deploy/
  authentik/blueprints/       Authentik group, scope, app, and policy skeletons
  compose/                    Module-scoped Docker Compose projects
  env/                        Tracked example env files only
  gitea/                      Gitea app.ini template
  minio/policies/             Service bucket policy templates
  nginx/                      Edge Nginx config, snippets, and route skeletons
  reports/                    Smoke report templates
  runbooks/                   Module runbooks
  scripts/                    Bootstrap, check, and backup scripts
```

## Execution Order

1. Create directories and Docker networks.
2. Start core services: Postgres, Redis, MinIO.
3. Bootstrap Postgres databases and MinIO buckets/policies.
4. Generate staging-only `/etc/hosts` entries and self-signed TLS files when using the hosts+self-signed gate.
5. Start edge Nginx after TLS placeholder certs exist.
6. Start Authentik and apply blueprints through the Authentik UI/API.
7. Create OIDC/proxy providers with module bootstrap scripts and write generated client secrets into server env files only.
8. Start app modules.
9. Seed demo/runtime baselines where applicable, such as Gitea/Plane demo data, the Nextcloud document hub, and the Grist research hub.
10. Run module checks.
11. Run backup dry-run and integrated smoke.

## Secret Policy

Only example files are tracked here. Do not commit real `.env`, TLS private keys, client secrets, tokens, activation URLs, or generated service-account credentials.

Use placeholders such as `change-me-generate-on-server` in tracked files. Store actual values under `/srv/lab-platform/env/` with restricted permissions.
