# Phase 3 Huly Pilot Report

Date: 2026-05-10
Host: current Docker host, runtime root `/opt/lab-stack`
Deployment commit: working tree, branch `huly/workspace-mvp`
Result: conditional-pass

## Summary

- Huly core self-host services are running behind the existing Nginx edge on `/opt/lab-stack`.
- Staging preflight passed with relaxed real-domain and external credential requirements.
- Runtime smoke passed: Huly containers are running, publish no direct host ports, Nginx serves the Huly route, and Authentik Huly OIDC discovery is reachable.
- Full pass still requires real DNS/TLS/SMTP from Phase 2, browser OIDC login validation, workspace seed completion, GitHub App credentials, Google Calendar credentials, Notion sample import, and one-week pilot usage.

## Automated Checks

Record command, timestamp, and result. Redact secret values.

```bash
sudo /opt/lab-stack/scripts/23-check-phase3-huly-preflight.sh
sudo docker compose -f /opt/lab-stack/compose/huly/docker-compose.yml --profile github --profile calendar up -d
sudo STAGING_IP=127.0.0.1 /opt/lab-stack/scripts/30-check-huly.sh
sudo /opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh
sudo /opt/lab-stack/scripts/32-check-huly-pilot.sh
```

Executed staging equivalents:

```bash
PHASE3_REQUIRE_REAL_DOMAINS=false PHASE3_REQUIRE_GITHUB=false PHASE3_REQUIRE_CALENDAR=false /opt/lab-stack/scripts/23-check-phase3-huly-preflight.sh
docker compose -f /opt/lab-stack/compose/huly/docker-compose.yml up -d
STAGING_IP=127.0.0.1 /opt/lab-stack/scripts/30-check-huly.sh
/opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh
PHASE3_REQUIRE_PILOT_FULL_PASS=false /opt/lab-stack/scripts/32-check-huly-pilot.sh
```

Observed runtime:

```text
huly-cockroach healthy, no host port
huly-redpanda healthy, no host port
huly-minio healthy, no host port
huly-elastic healthy, no host port
huly-front/account/transactor/workspace/fulltext/collaborator/rekoni/stats/kvs running, no host ports
nginx serves https://huly.lab.example.ac.kr/ with HTTP 200 using --resolve
Huly account OIDC callback route reached account service with HTTP 405
Authentik Huly OIDC discovery returned HTTP 200
```

## OIDC Login

- Status: runtime route ready, browser login pending
- Evidence: account service discovered Authentik issuer and registered OIDC strategy; `30-check-huly.sh` reached callback route and discovery.
- Notes: staging uses self-signed TLS, so `/opt/lab-stack/env/30-huly.env` has `HULY_OIDC_TLS_REJECT_UNAUTHORIZED=0`. Set it back to `1` after trusted TLS is installed.

## Workspace Seed

- Status: seed bundle ready, manual workspace creation pending
- Channels: `#general`, `#research`, `#paper`, `#infra`, `#random`
- Projects: `Experiments`, `Papers`, `Infrastructure`, `Datasets`, `Onboarding`
- Evidence: `/opt/lab-stack/scripts/31-bootstrap-huly-workspace.sh` found all seed artifacts under `/opt/lab-stack/huly/seed`.
- Notes: no stable upstream Huly self-host API/CLI was found, so seed is deterministic manual content.

## GitHub Sync

- Status: pending external credentials
- Pilot repository:
- Huly to GitHub issue:
- GitHub to Huly update:
- PR event:
- Notes: `HULY_ENABLE_GITHUB=false` in current staging env. Full pass requires GitHub App credentials and one repository roundtrip.

## Google Calendar

- Status: pending external credentials
- OAuth redirect URI: `https://huly.lab.example.ac.kr/_calendar/signin/code`
- Event create/update evidence:
- Notes: `HULY_ENABLE_CALENDAR=false` in current staging env. Full pass requires Google OAuth credential JSON and event sync evidence.

## Notion Sample

- Status: pending manual scrub/import
- Page count:
- Scrub checklist:
- Import method:
- Formatting issues:
- Notes: scrub/import checklist exists under `/opt/lab-stack/huly/notion-sample`.

## Gantt Or Timeline

- Status: pending
- Evidence:
- Fallback decision required: pending
- Notes:

## Pilot Usage

- Status: pending one-week pilot
- Pilot users: 0
- Pilot window:
- Meeting notes used:
- Task updates used:
- GitHub issue used:
- Attachments used:
- Blockers:

## Gate Decision

- Full-pass conditions met: no
- Conditional-pass reason: Huly core deploy and runtime smoke passed in staging, but external credentials and human browser/pilot checks are not complete.
- Stop/fail reason:
- Next action: complete browser OIDC login, seed the workspace, add GitHub and Google credentials, then rerun full-pass checks.
