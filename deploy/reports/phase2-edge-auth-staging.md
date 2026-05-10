# Phase 2 Edge/Auth Staging Report

Date: 2026-05-10
Host: current Docker host, runtime root `/opt/lab-stack`
Deployment commit: `f24aae4` plus uncommitted Phase 2 working tree
Result: conditional-pass

## Summary

- Gate result: Edge/Auth container-level gate passed on `/opt/lab-stack` for core Postgres/Redis, Nginx, Authentik reachability/groups, and Huly/MinIO/HF UI OIDC discovery.
- Blockers: strict operational preflight still fails because the host uses `*.lab.example.ac.kr` placeholders, a self-signed staging certificate, and placeholder SMTP values.
- Conditional-pass notes: Authentik admin 2FA, invitation-only enrollment, SMTP delivery, school DNS, and school TLS were not manually validated.
- Next phase handoff: Phase 3 may use the validated `AUTH_DOMAIN=auth.lab.example.ac.kr` staging surface pattern and issuer/provider URL pattern. Real DNS, TLS, SMTP, redirect URIs, and client secrets must replace the generated `/opt/lab-stack/env` placeholder values before full-pass.

## Preflight

- Phase 0 readiness: strict operational preflight failed on example domains and placeholder SMTP/OIDC redirect values.
- Phase 1 host skeleton: repo scripts and layout copied into `/opt/lab-stack`; containers were recreated against `/opt/lab-stack` bind mounts.
- Runtime root: `/opt/lab-stack`.
- Networks: `labstack_public`, `labstack_backend`, `labstack_data` created and inspected.
- Historical v0.x names absent from active runtime: compose/script active path uses `LAB_STACK_ROOT` and `labstack_*`; legacy route files remain inactive.
- No real secrets in git/history/report: checked; generated throwaway values stayed only in `/opt/lab-stack/env/*.env` and `/tmp/lab-stack-phase2/env/*.env`.

## Edge

- Certificate source: generated local self-signed staging cert.
- Certificate SHA256 fingerprint: `D5:79:EE:AE:EE:E7:1F:84:5B:CD:A4:91:FF:22:D6:B5:9E:A7:9C:6B:90:1E:AE:98:47:41:30:FC:38:0B:68:2A`.
- Certificate validity: `May 10 01:29:10 2026 GMT` to `May 10 01:29:10 2027 GMT`; subject `CN = auth.lab.example.ac.kr`.
- TLS key permissions for `/opt/lab-stack/certs/private/staging.key`: `0600 root:root`.
- Nginx config test: passed.
- HTTP to HTTPS redirect: `HTTP/1.1 301 Moved Permanently` to `https://auth.lab.example.ac.kr/`.
- Auth host HTTPS: `/api/v3/root/config/` returned HTTP 200 with `--resolve auth.lab.example.ac.kr:443:127.0.0.1`.
- Published ports: Nginx published 80 and 443; Postgres/Redis/Auth containers did not publish host ports.
- Unexpected ports: no app unexpected ports; host already had SSH/local resolver/listener ports `22`, `53`, and `35085`.

## Authentik

- Containers: `authentik-server` and `authentik-worker` healthy with `/opt/lab-stack/data/authentik` bind mounts.
- Root config endpoint: HTTP 200 through Nginx.
- Admin 2FA: not manually validated in this fallback run.
- Groups: `lab-admin`, `lab-member`, `lab-collab`, `lab-guest` passed `20-check-authentik.sh`.
- Self-signup blocked: not manually validated in this fallback run.
- Invitation enrollment: not manually validated in this fallback run.
- SMTP test: not validated; `/opt/lab-stack/env/20-authentik.env` still uses placeholder SMTP values.
- Admin notification: not validated.

## OIDC Handoff

- Huly client metadata: Authentik application and OAuth provider `huly` exist on `/opt/lab-stack` validation.
- MinIO client metadata: Authentik application and OAuth provider `minio` exist on `/opt/lab-stack` validation.
- HF UI client metadata: Authentik application and OAuth provider `hf-ui` exist on `/opt/lab-stack` validation.
- Redirect URI review: `/opt` run used placeholder HTTPS callback patterns only; operator must replace them with app-version-correct production callbacks in `/opt/lab-stack/env/20-authentik.env`.
- Client secrets stored only in server env: generated throwaway secrets stayed under `/opt/lab-stack/env/20-authentik.env`; real full-pass secrets must live only under `/opt/lab-stack/env/*.env`.

## Validation Commands

Record timestamp, command, and pass/fail. Redact secret values.

```bash
bash -n deploy/scripts/10-check-edge.sh deploy/scripts/20-check-authentik.sh deploy/scripts/lib/common.sh
git diff --check
sudo docker exec nginx nginx -t
sudo /opt/lab-stack/scripts/04-check-core.sh
sudo /opt/lab-stack/scripts/10-check-edge.sh
sudo /opt/lab-stack/scripts/20-check-authentik.sh
curl -Ik http://$AUTH_DOMAIN/
curl -ksSfL https://$AUTH_DOMAIN/api/v3/root/config/ >/dev/null
ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://' | sort -n | uniq
```

Executed fallback equivalents:

```bash
LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env /tmp/lab-stack-phase2/scripts/04-check-core.sh
LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env /tmp/lab-stack-phase2/scripts/10-check-edge.sh
STAGING_IP=127.0.0.1 LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env COMPOSE_FILE=/tmp/lab-stack-phase2/compose/authentik/docker-compose.yml /tmp/lab-stack-phase2/scripts/20-check-authentik.sh
PHASE2_REQUIRE_SMTP=false LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env deploy/scripts/19-check-phase2-preflight.sh
LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env deploy/scripts/22-bootstrap-authentik-oidc.sh
STAGING_IP=127.0.0.1 LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env deploy/scripts/20-check-authentik.sh
PHASE2_REQUIRE_SMTP=false STAGING_IP=127.0.0.1 LAB_STACK_ROOT=/tmp/lab-stack-phase2 ENV_DIR=/tmp/lab-stack-phase2/env deploy/scripts/96-check-all.sh
curl -Ik --resolve auth.lab.example.ac.kr:80:127.0.0.1 http://auth.lab.example.ac.kr/
curl -ksS --resolve auth.lab.example.ac.kr:443:127.0.0.1 https://auth.lab.example.ac.kr/api/v3/root/config/
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
openssl x509 -in /tmp/lab-stack-phase2/certs/staging.crt -noout -fingerprint -sha256 -dates -subject
stat -c '%a %U:%G %n' /tmp/lab-stack-phase2/certs/private/staging.key
LAB_STACK_ROOT=/opt/lab-stack ENV_DIR=/opt/lab-stack/env deploy/scripts/19-check-phase2-preflight.sh
```

Executed `/opt/lab-stack` equivalents:

```bash
/opt/lab-stack/scripts/19-check-phase2-preflight.sh
PHASE2_REQUIRE_REAL_DOMAINS=false PHASE2_REQUIRE_SMTP=false /opt/lab-stack/scripts/19-check-phase2-preflight.sh
/opt/lab-stack/scripts/04-check-core.sh
/opt/lab-stack/scripts/02-bootstrap-postgres.sh
/opt/lab-stack/scripts/10-check-edge.sh
/opt/lab-stack/scripts/22-bootstrap-authentik-oidc.sh
STAGING_IP=127.0.0.1 /opt/lab-stack/scripts/20-check-authentik.sh
PHASE2_REQUIRE_REAL_DOMAINS=false PHASE2_REQUIRE_SMTP=false STAGING_IP=127.0.0.1 /opt/lab-stack/scripts/96-check-all.sh
curl -Ik --resolve auth.lab.example.ac.kr:80:127.0.0.1 http://auth.lab.example.ac.kr/
curl -ksSfL --resolve auth.lab.example.ac.kr:443:127.0.0.1 https://auth.lab.example.ac.kr/api/v3/root/config/ | wc -c
```

Observed running containers after validation:

```text
authentik-server   Up (healthy)
authentik-worker   Up (healthy)
nginx              Up (healthy), publishes 80/443
postgres           Up (healthy), internal 5432 only
redis              Up (healthy), internal 6379 only
```

Observed active bind mounts:

```text
nginx: /opt/lab-stack/nginx, /opt/lab-stack/certs, /opt/lab-stack/logs/nginx
authentik-server: /opt/lab-stack/data/authentik and /opt/lab-stack/authentik/blueprints
```

Observed `/opt` OIDC state after validation:

```text
apps=hf-ui,huly,minio
providers=hf-ui,huly,minio
```

Observed operational preflight state:

```text
strict preflight exit=1
example domains remain in ROOT_DOMAIN/AUTH_DOMAIN/HULY_DOMAIN/FILES_DOMAIN/HF_DOMAIN
placeholder SMTP remains in AUTHENTIK_EMAIL__HOST, AUTHENTIK_EMAIL__USERNAME, AUTHENTIK_EMAIL__FROM
placeholder OIDC redirect URIs remain under *.lab.example.ac.kr
```

## Rollback State

- Authentik stop tested: not stopped; containers left running for inspection.
- Edge stop tested: not stopped; Nginx left running for inspection.
- Data/logs preserved: `/opt/lab-stack`, `/tmp/lab-stack-phase2`, and Docker containers remain present.
- Secrets left unchanged: no rotation after generation.
- Route-level rollback notes: active Nginx loads only `00-http-redirect.conf` and `10-authentik.conf`; legacy app routes are inactive.

## Follow-Up

- Phase 3 Huly inputs: `AUTH_DOMAIN=auth.lab.example.ac.kr`; issuer/provider URL pattern `https://auth.lab.example.ac.kr/application/o/<slug>/`; server-only client secret path `/opt/lab-stack/env/20-authentik.env`.
- Open risks: school DNS/TLS/SMTP are still absent; Authentik 2FA/enrollment/SMTP setup remains manual/pending; production redirect URIs must be confirmed per app version before full-pass.
- Owners: next operator should replace the example domains, install the school certificate, configure real SMTP, run strict `19-check-phase2-preflight.sh`, and then rerun the same gate without relaxed flags.
