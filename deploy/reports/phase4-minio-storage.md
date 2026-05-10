# Phase 4 MinIO Storage Report

Date: 2026-05-10
Host: current Docker host, runtime root `/opt/lab-stack`
Deployment commit: working tree
Result: conditional-pass (staging)

## Summary

- Shared core MinIO is the Phase 4 storage target for models, datasets,
  artifacts, public downloads, and backup smoke validation.
- Huly's internal `huly-minio` remains Huly-only.
- Full pass still requires real DNS/TLS, browser OIDC login evidence, and
  role-specific Console checks with `lab-member` and `lab-guest`.
- `/opt/lab-stack` staging checks passed with relaxed real-domain/SMTP flags for
  the current example-domain, self-signed certificate environment.

## Automated Checks

Record command, timestamp, and result. Redact secret values.

```bash
bash -n deploy/scripts/33-bootstrap-minio-storage.sh \
  deploy/scripts/34-check-minio-storage.sh \
  deploy/scripts/35-check-minio-backup-smoke.sh \
  deploy/scripts/96-check-all.sh

docker compose -f deploy/compose/core/docker-compose.yml --profile minio config
git diff --check
```

Executed static checks in this workspace:

```text
bash -n phase4 scripts and 96-check-all: passed
docker compose --profile minio config with example env loaded: passed
DRY_RUN=true 33-bootstrap-minio-storage.sh with copied env examples: passed
git diff --check: passed
secret pattern scan for common token/private-key prefixes: no credible secrets found
```

Executed staging checks:

```bash
/opt/lab-stack/scripts/33-bootstrap-minio-storage.sh
STAGING_IP=127.0.0.1 PHASE4_REQUIRE_REAL_DOMAINS=false \
  /opt/lab-stack/scripts/34-check-minio-storage.sh
/opt/lab-stack/scripts/35-check-minio-backup-smoke.sh
STAGING_IP=127.0.0.1 \
  PHASE2_REQUIRE_REAL_DOMAINS=false \
  PHASE2_REQUIRE_SMTP=false \
  PHASE4_REQUIRE_REAL_DOMAINS=false \
  LABSTACK_INCLUDE_MINIO=true \
  /opt/lab-stack/scripts/96-check-all.sh
```

Observed staging result:

```text
33-bootstrap-minio-storage.sh: created/confirmed buckets, enabled versioning,
created policies, set lab-public anonymous download, set private buckets private.
34-check-minio-storage.sh: passed with STAGING_IP=127.0.0.1 and
PHASE4_REQUIRE_REAL_DOMAINS=false.
35-check-minio-backup-smoke.sh: passed.
96-check-all.sh: passed with STAGING_IP=127.0.0.1,
PHASE2_REQUIRE_REAL_DOMAINS=false, PHASE2_REQUIRE_SMTP=false,
PHASE4_REQUIRE_REAL_DOMAINS=false, LABSTACK_INCLUDE_MINIO=true.
```

Runtime fixes applied during staging:

- Mounted `/opt/lab-stack/certs/staging.crt` into MinIO's CA directory so OIDC
  discovery trusts the self-signed Authentik staging certificate.
- Added `30-minio-storage.conf` to the active `nginx.conf` include list and
  recreated only the Nginx container because `nginx.conf` is a single-file bind
  mount.

## Buckets And Versioning

- `lab-models`: exists, versioning enabled
- `lab-datasets`: exists, versioning enabled
- `lab-artifacts`: exists, versioning enabled
- `lab-public`: exists, versioning enabled
- `lab-backups`: exists, versioning enabled

## Policies

- `consoleAdmin`: built-in MinIO policy for `lab-admin` through OIDC claim.
- `lab-storage-member-rw`: `lab-member` and `lab-collab` access to working
  storage buckets.
- `lab-public-read`: authenticated read policy for `lab-public`.
- `hf-ui-storage-rw`: future HF-like UI service policy.
- Anonymous: download-only on `lab-public`; private buckets deny anonymous
  access.

## OIDC Login

- Status: provider bootstrapped, browser validation pending
- MinIO callback: `https://files.lab.example.ac.kr/oauth_callback`
- Claim name: `policy`
- Admin mapping: `lab-admin` -> `consoleAdmin`
- Member mapping: `lab-member`/`lab-collab` -> `lab-storage-member-rw`
- Guest block: `lab-guest` is excluded by the active application policy

## S3 API Smoke

- Health: `minio` running and healthy
- No host ports: passed
- Upload/stat/download: passed against `lab-artifacts`
- Private anonymous deny: passed with HTTP 403
- Public anonymous download: passed through `https://s3.lab.example.ac.kr`

## Backup Smoke

- Source bucket: `lab-backups`
- Mirror root: `/mnt/backup/lab/minio-smoke`
- Sample object: `smoke/phase4-backup/sample-20260510T135925Z-3503844.txt`
- Size/checksum: matched

## Gate Decision

- Full-pass conditions met: no
- Conditional-pass reason: shared core MinIO, bucket/policy automation, S3
  public/private behavior, and backup smoke passed in staging, but production
  DNS/TLS and browser OIDC role evidence are not complete.
- Stop/fail reason:
- Next action: complete browser OIDC checks for `lab-member` and `lab-guest`
  after real DNS/TLS are ready.
