# Phase 2 Edge/Auth Staging

Phase 2 brings up the smallest public surface for the Huly workspace MVP:
HTTPS Nginx plus Authentik identity. It is staging-first: validate on the target
staging host, record evidence, then decide whether Phase 3 Huly can proceed.

`edge-nginx.md` and `authentik.md` are historical v0.x references. Use this file
for active Phase 2 execution.

## Scope

Active target:

```text
LAB_STACK_ROOT=/opt/lab-stack
networks: labstack_public, labstack_backend, labstack_data
public ports: 80, 443 only
```

Phase 2 does:

- copy tracked deploy files into the staging root
- create server-only env files from examples
- install school TLS files or an approved staging certificate
- start Nginx for redirect and `AUTH_DOMAIN`
- start Authentik with SMTP, groups, 2FA, invitation-only enrollment, and OIDC metadata
- record validation in `deploy/reports/phase2-edge-auth-staging.md`

Phase 2 does not start Huly, MinIO app flows, HF UI, Overleaf, Plane, Gitea,
Nextcloud, or MLflow.

## Preflight

Run from the repository before host work:

```bash
bash -n deploy/scripts/10-check-edge.sh \
  deploy/scripts/20-check-authentik.sh \
  deploy/scripts/19-check-phase2-preflight.sh \
  deploy/scripts/22-bootstrap-authentik-oidc.sh \
  deploy/scripts/lib/common.sh

git diff --check
```

Staging must also pass these checks before starting services:

```bash
sudo test -d /opt/lab-stack
sudo test -d /opt/lab-stack/env
sudo test -r /opt/lab-stack/env/00-global.env
sudo test -r /opt/lab-stack/env/10-core.env
sudo test -r /opt/lab-stack/env/20-authentik.env
sudo test -r /opt/lab-stack/nginx/nginx.conf
sudo test -r /opt/lab-stack/certs/staging.crt
sudo test -r /opt/lab-stack/certs/private/staging.key
test "$(sudo stat -c '%a' /opt/lab-stack/certs/private/staging.key)" -le 600
test "$(sudo stat -c '%u:%g' /opt/lab-stack/data/authentik/media)" = "1000:1000"
docker network inspect labstack_public labstack_backend labstack_data >/dev/null
sudo /opt/lab-stack/scripts/19-check-phase2-preflight.sh
```

If compose files or scripts still require `LAB_PLATFORM_ROOT`, `lab_public`,
`lab_backend`, `lab_data`, or `/srv/lab-platform`, stop and reconcile the runtime
contract before live execution. Those names belong to the older v0.x layout.
If tracked Nginx files still contain `lab.example.ac.kr`, replace the placeholder
with the approved staging domain before exposing the host.
`19-check-phase2-preflight.sh` fails on `example.*` values by default. For a
non-production self-signed rehearsal only, set
`PHASE2_REQUIRE_REAL_DOMAINS=false PHASE2_REQUIRE_SMTP=false`; any gate that uses
those relaxed flags is conditional-pass, not operational full-pass.

## Sub-Agent Sequence

Use one small handoff per step. Each sub-agent leaves command output, timestamps,
and blockers in the staging report.

1. P2-A Preflight: confirm Phase 0 and Phase 1 are complete, root/network names
   match `/opt/lab-stack` and `labstack_*`, and no real secrets are in git.
2. P2-B Edge: install certificate files, start only Nginx, verify HTTPS redirect,
   `AUTH_DOMAIN`, TLS expiry, and public ports.
3. P2-C Auth: start Authentik, complete initial admin setup, enforce admin 2FA,
   apply groups, disable self-signup, configure invitation-only enrollment, and
   send SMTP test mail.
4. P2-D OIDC Handoff: create Huly, MinIO, and HF UI client metadata with fixed
   redirect URIs. Store generated secrets only in server env files.
5. P2-E Gate: run validation commands, update
   `deploy/reports/phase2-edge-auth-staging.md`, and declare pass, conditional
   pass, or stop.

Do not continue to the next step after a failed gate unless the report names the
owner, workaround, and rollback state.

## Staging Commands

Copy the tracked deploy tree into `/opt/lab-stack` using the approved operator
method, then create server-only env files:

```bash
sudo cp -n /opt/lab-stack/env/00-global.env.example /opt/lab-stack/env/00-global.env
sudo cp -n /opt/lab-stack/env/10-core.env.example /opt/lab-stack/env/10-core.env
sudo cp -n /opt/lab-stack/env/20-authentik.env.example /opt/lab-stack/env/20-authentik.env
sudo chmod 0640 /opt/lab-stack/env/*.env
sudo chmod 0600 /opt/lab-stack/certs/private/staging.key
```

Generate all placeholder values on the staging host. Never paste generated
passwords, tokens, client secrets, SMTP credentials, or TLS private keys into git,
history, issue comments, chat, or reports.

For Phase 2 full pass, also set these server-only OIDC values in
`/opt/lab-stack/env/20-authentik.env` before running the preflight:

```bash
AUTHENTIK_PHASE2_OIDC_APPS=huly,minio,hf-ui
AUTHENTIK_CHECK_DISCOVERY_SLUGS=huly,minio,hf-ui
HULY_OIDC_CLIENT_ID=huly
HULY_OIDC_CLIENT_SECRET=<generated on server>
HULY_OIDC_REDIRECT_URIS=https://huly.lab.example.ac.kr/_accounts/auth/openid/callback
MINIO_OIDC_CLIENT_ID=minio
MINIO_OIDC_CLIENT_SECRET=<generated on server>
MINIO_OIDC_REDIRECT_URIS=<fixed MinIO Console callback URL>
HF_UI_OIDC_CLIENT_ID=hf-ui
HF_UI_OIDC_CLIENT_SECRET=<generated on server>
HF_UI_OIDC_REDIRECT_URIS=<fixed HF UI callback URL>
```

For an internal staging gate without the school certificate, generate a temporary
self-signed certificate on the staging host:

```bash
sudo LAB_STACK_ROOT=/opt/lab-stack /opt/lab-stack/scripts/05-create-self-signed-cert.sh
```

Start Edge/Auth only after the preflight is clean. Authentik needs shared
Postgres and Redis, so Phase 2 starts those core services but leaves MinIO behind
its later-phase compose profile.

```bash
sudo LAB_STACK_ROOT=/opt/lab-stack /opt/lab-stack/scripts/01-create-networks.sh
sudo LAB_STACK_ROOT=/opt/lab-stack /opt/lab-stack/scripts/00-create-directories.sh

cd /opt/lab-stack/compose/core
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/10-core.env \
  -f /opt/lab-stack/compose/core/docker-compose.yml \
  -p lab_core \
  up -d postgres redis

sudo /opt/lab-stack/scripts/04-check-core.sh
sudo /opt/lab-stack/scripts/02-bootstrap-postgres.sh

cd /opt/lab-stack/compose/edge
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  -f /opt/lab-stack/compose/edge/docker-compose.yml \
  -p lab_edge \
  up -d

cd /opt/lab-stack/compose/authentik
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/10-core.env \
  --env-file /opt/lab-stack/env/20-authentik.env \
  -f /opt/lab-stack/compose/authentik/docker-compose.yml \
  -p lab_authentik \
  up -d
```

Do not enable legacy app routes.

Bootstrap the Phase 2 OIDC providers after Authentik is healthy and the manual
security baseline has been configured:

```bash
sudo /opt/lab-stack/scripts/22-bootstrap-authentik-oidc.sh
sudo /opt/lab-stack/scripts/20-check-authentik.sh
```

## Validation

Run and paste summarized results into the report:

```bash
sudo docker exec nginx nginx -t
sudo /opt/lab-stack/scripts/19-check-phase2-preflight.sh
sudo /opt/lab-stack/scripts/04-check-core.sh
sudo /opt/lab-stack/scripts/10-check-edge.sh
sudo /opt/lab-stack/scripts/20-check-authentik.sh

curl -Ik http://$AUTH_DOMAIN/
curl -ksSfL https://$AUTH_DOMAIN/api/v3/root/config/ >/dev/null
ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://' | sort -n | uniq
```

For full pass, OIDC providers are created during P2-D and
`AUTHENTIK_CHECK_DISCOVERY_SLUGS=huly,minio,hf-ui` must pass. Huly's Phase 3
redirect URI is `https://$HULY_DOMAIN/_accounts/auth/openid/callback`.

Manual validation:

- admin login requires 2FA
- self-signup without invitation is blocked
- invitation link creates a test user
- test user receives email and has the expected group claim
- SMTP test and admin notification are received
- Huly, MinIO, and HF UI client metadata have fixed redirect URIs

Gate passes only when ports are limited to 80/443, Authentik is reachable over
HTTPS, invitation-only identity works, and no secret is written outside the
server-only env/cert paths.

## Secret Policy

- Real env files live only under `/opt/lab-stack/env/*.env`.
- TLS private key lives only under `/opt/lab-stack/certs/private/staging.key` with
  mode `0600` or stricter.
- Authentik bootstrap token and generated OIDC client secrets are never committed.
- Reports may include hostnames, command names, pass/fail state, redacted
  fingerprints, and timestamps. They must not include secret values.
- Rotation is a deliberate maintenance task. Do not rotate secrets during incident
  triage unless containment requires it and the decision is recorded.

## Rollback

Prefer stop over delete:

```bash
cd /opt/lab-stack/compose/authentik
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  --env-file /opt/lab-stack/env/10-core.env \
  --env-file /opt/lab-stack/env/20-authentik.env \
  -f /opt/lab-stack/compose/authentik/docker-compose.yml \
  -p lab_authentik \
  stop

cd /opt/lab-stack/compose/edge
sudo docker compose \
  --env-file /opt/lab-stack/env/00-global.env \
  -f /opt/lab-stack/compose/edge/docker-compose.yml \
  -p lab_edge \
  stop
```

Preserve `/opt/lab-stack/env`, `/opt/lab-stack/certs`, Authentik data,
container logs, and Nginx logs until the incident owner classifies them. If only
one Nginx route is bad, move that route out of `nginx/conf.d`, run
`sudo docker exec nginx nginx -t`, then reload Nginx.

## Exit Criteria

- Staging report is complete.
- Edge/Auth validation commands pass on `/opt/lab-stack`; any documented
  conditional-pass reason means the phase is not yet operational full-pass.
- Huly Phase 3 receives `AUTH_DOMAIN`, issuer URL, client IDs, redirect URIs, and
  the location of server-only client secrets.
- Any blocker has an owner and rollback state.
