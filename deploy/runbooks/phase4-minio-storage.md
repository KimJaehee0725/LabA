# Phase 4 MinIO Storage Runbook

This runbook promotes the shared core `minio` container to the active storage
layer for lab models, datasets, artifacts, public downloads, and backup smoke
testing. Huly's internal `huly-minio` remains Huly-only.

## Scope

- Console: `https://files.lab.example.ac.kr`
- S3 API: `https://s3.lab.example.ac.kr`
- Runtime root: `/opt/lab-stack`
- Buckets: `lab-models`, `lab-datasets`, `lab-artifacts`, `lab-public`, `lab-backups`
- Policies: `lab-storage-member-rw`, `lab-public-read`, `hf-ui-storage-rw`
- OIDC claim: `policy`
- Public access: anonymous download-only on `lab-public`

## Server Preparation

1. Copy updated deploy files to `/opt/lab-stack`.
2. Create directories, including the MinIO data root and backup smoke root:

```bash
sudo /opt/lab-stack/scripts/00-create-directories.sh
```

3. Create `/opt/lab-stack/env/35-minio-storage.env` from
   `deploy/env/35-minio-storage.env.example`.
4. Generate and store server-only values in `/opt/lab-stack/env/10-core.env`
   and `/opt/lab-stack/env/20-authentik.env`:

```bash
openssl rand -hex 24  # MINIO_ROOT_USER, if using generated root usernames
openssl rand -hex 32  # MINIO_ROOT_PASSWORD
openssl rand -hex 32  # MINIO_OIDC_CLIENT_SECRET
```

5. Confirm `/opt/lab-stack/env/20-authentik.env` contains:

```bash
MINIO_OIDC_CLIENT_ID=minio
MINIO_OIDC_REDIRECT_URIS=https://${FILES_DOMAIN}/oauth_callback
MINIO_OIDC_SCOPES=openid,email,profile,groups,policy
```

Do not record generated root credentials, client secrets, or access keys in git,
reports, screenshots, or history.

## Authentik OIDC

Re-bootstrap OIDC providers after the MinIO values are set:

```bash
sudo /opt/lab-stack/scripts/22-bootstrap-authentik-oidc.sh
```

Expected MinIO policy claim behavior:

- `lab-admin` gets `consoleAdmin`.
- `lab-member` and `lab-collab` get `lab-storage-member-rw`.
- `lab-guest` is blocked by the application policy and receives no useful
  MinIO policy if a token is ever issued.

## Start Shared MinIO

The compose file mounts `/opt/lab-stack/certs/staging.crt` into MinIO's custom
CA directory so staging OpenID discovery works with the self-signed Phase 2
certificate. With a trusted production certificate, this mount is harmless and
can remain in place.

```bash
sudo bash -lc '
set -a
. /opt/lab-stack/env/00-global.env
. /opt/lab-stack/env/10-core.env
. /opt/lab-stack/env/20-authentik.env
. /opt/lab-stack/env/35-minio-storage.env
set +a
docker compose -f /opt/lab-stack/compose/core/docker-compose.yml --profile minio up -d minio
'
```

Reload Nginx after copying `30-minio-storage.conf`:

```bash
sudo docker exec nginx nginx -t
sudo docker exec nginx nginx -s reload
```

If `nginx.conf` itself changed and is mounted as a single file, recreate only the
Nginx container so Docker picks up the new host file inode:

```bash
sudo bash -lc '
set -a
. /opt/lab-stack/env/00-global.env
set +a
docker compose -f /opt/lab-stack/compose/edge/docker-compose.yml up -d --force-recreate nginx
'
```

## Bootstrap Buckets And Policies

```bash
sudo /opt/lab-stack/scripts/33-bootstrap-minio-storage.sh
```

Expected:

- All five buckets exist.
- Versioning is enabled for all Phase 4 buckets.
- `lab-storage-member-rw`, `lab-public-read`, and `hf-ui-storage-rw` exist.
- `lab-public` allows anonymous download.
- Private buckets have anonymous policy `none`.

## Automated Checks

Strict mode with real domains:

```bash
sudo /opt/lab-stack/scripts/34-check-minio-storage.sh
sudo /opt/lab-stack/scripts/35-check-minio-backup-smoke.sh
```

Staging mode before real DNS/TLS:

```bash
sudo STAGING_IP=127.0.0.1 \
  PHASE4_REQUIRE_REAL_DOMAINS=false \
  /opt/lab-stack/scripts/34-check-minio-storage.sh

sudo /opt/lab-stack/scripts/35-check-minio-backup-smoke.sh

sudo STAGING_IP=127.0.0.1 \
  PHASE2_REQUIRE_REAL_DOMAINS=false \
  PHASE2_REQUIRE_SMTP=false \
  PHASE4_REQUIRE_REAL_DOMAINS=false \
  LABSTACK_INCLUDE_MINIO=true \
  /opt/lab-stack/scripts/96-check-all.sh
```

## Browser Smoke

Use a private browser session.

1. Open `https://files.lab.example.ac.kr`.
2. Confirm Authentik appears under the Console authentication options.
3. Sign in as a `lab-member` and confirm only allowed buckets are visible.
4. Sign in or attempt launch as `lab-guest` and confirm Console access is
   blocked.
5. Confirm a `lab-public` object downloads anonymously from
   `https://s3.lab.example.ac.kr/lab-public/...`.
6. Confirm an object in `lab-artifacts` or another private bucket fails
   anonymously with HTTP 401 or 403.

## Report And Gate

Record evidence in `/opt/lab-stack/reports/phase4-minio-storage.md`.

Conditional pass requires:

- Static checks pass.
- Shared MinIO starts without direct host ports.
- Bucket, versioning, policy, public download, private deny, and backup smoke
  checks pass in staging with `PHASE4_REQUIRE_REAL_DOMAINS=false`.

Full pass also requires real DNS/TLS, browser OIDC evidence, `lab-member`
Console access verification, and `lab-guest` denial evidence.

## Rollback

Stop only the shared MinIO profile:

```bash
sudo docker compose -f /opt/lab-stack/compose/core/docker-compose.yml --profile minio stop minio
```

Then remove or disable `30-minio-storage.conf` and reload Nginx. Preserve:

- `/mnt/hdd/minio`
- `/opt/lab-stack/env/10-core.env`
- `/opt/lab-stack/env/20-authentik.env`
- `/opt/lab-stack/env/35-minio-storage.env`
- `/opt/lab-stack/reports/phase4-minio-storage.md`
- `/mnt/backup/lab/minio-smoke`

Do not rotate secrets during rollback unless there is a confirmed exposure.
