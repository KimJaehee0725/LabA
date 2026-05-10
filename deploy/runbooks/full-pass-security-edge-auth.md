# Full-Pass Security and Edge/Auth Readiness

Status: staging conditional-pass, full-pass pending.

Date: 2026-05-10
Current branch: `huly/workspace-mvp`
Runtime target: `/opt/lab-stack`

This checklist gates a draft PR and the Phase 2 Edge/Auth promotion from
staging conditional-pass to operational full-pass. The current staging evidence
in `deploy/reports/phase2-edge-auth-staging.md` is acceptable only as a
conditional-pass because real DNS, school TLS, real SMTP, and manual Authentik
browser evidence are still pending.

## Credential Safety Checklist

Stop before PR promotion if any item below is unresolved:

- Revoke and rotate the exposed GitHub token. Treat any token pasted into chat,
  shell history, logs, screenshots, reports, browser forms, or issue comments as
  exposed even if it is not in git.
- Rotate the sudo password that was exposed during staging coordination. Do not
  record the replacement value in this repository, reports, PR text, chat, or
  shell history.
- Confirm staging bypass tokens, OIDC client secrets, Authentik bootstrap
  values, SMTP credentials, Redis/Postgres passwords, service keys, and TLS
  private keys exist only on the server under approved server-only paths such as
  `/opt/lab-stack/env/*.env`, `/opt/lab-stack/secrets/*`, and
  `/opt/lab-stack/certs/private/*`.
- Never copy real secret values into git, `deploy/reports`, PR descriptions,
  review comments, screenshots, browser evidence, terminal transcripts, or
  validation notes. Evidence may name variables and paths, but not values.
- If a secret value is observed outside server-only storage, classify it as real,
  revoke or rotate it, record the action without the value, and rerun the scans
  below before continuing.

## Secret Scans

Run these read-only checks from the repository root before marking the PR ready
for review:

```bash
git status --short --branch
git diff --check
git diff --cached --check

rg -n --hidden --glob '!.git' \
  'ghp_|github_pat_|-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|client_secret[=:][^<[:space:]]+|password[=:][^<[:space:]]+|token[=:][^<[:space:]]+' \
  .

rg -n --hidden --glob '!.git' \
  'AUTHENTIK_.*(PASSWORD|TOKEN|SECRET)|OIDC_CLIENT_SECRET|SMTP|PRIVATE_KEY|SESSION_SECRET|ACCESS_KEY|SECRET_KEY' \
  deploy docs
```

If `gitleaks` is installed, also run:

```bash
gitleaks detect --source . --no-git --redact
gitleaks detect --source . --redact
```

Classify each hit before proceeding:

- Placeholder: values such as `change-me-*`, `CHANGE-ME-*`, `todo-*`,
  `<generated on server>`, `<generated-server-only-secret>`, example domains,
  example SMTP users, variable names, script code that reads env vars, or
  documentation that describes where a secret belongs. These may remain if they
  are clearly non-secret.
- Real secret: high-entropy values, live GitHub tokens, private keys, OAuth
  client secrets, passwords, SMTP credentials, service-account JSON, bearer
  tokens, activation URLs, or filled `.env` values. These must be removed from
  git-facing surfaces and rotated or revoked.
- Ambiguous: anything that could plausibly authenticate. Treat as real until the
  owner proves it is a placeholder or a deliberately invalid test fixture.

Do not paste scan output containing candidate secret values into reports. Record
only file path, variable name, classification, action taken, and pass/fail.

## Draft PR Safety Checklist

Before opening or updating the draft PR:

- Branch is `huly/workspace-mvp` or another named feature branch, not `main`.
- Working tree contains only intended files. At the time this runbook was added,
  unrelated history files were already modified; do not include or revert other
  workers' changes unless explicitly instructed.
- Commits are scoped and message titles explain the deployment/readiness change.
- PR title names the Phase 2/full-pass readiness work, for example
  `deploy: add full-pass Edge/Auth readiness checklist`.
- PR body includes the current status: staging conditional-pass, full-pass
  pending until real DNS, school TLS, SMTP, secret rotation, and browser evidence
  are complete.
- PR body lists validation commands run and their summarized results. Redact
  secret values and avoid screenshots that expose credentials.
- PR body calls out the required rotations: exposed GitHub token and sudo
  password.
- No real `.env` files, TLS private keys, service keys, generated OIDC client
  secrets, SMTP credentials, or bypass tokens are tracked.
- Before changing from draft to ready-for-review, rerun secret scans,
  `git diff --check`, shell syntax checks, and the strict Phase 2 sequence below.

## Phase 2 Strict Mode Sequence

Use strict mode for full-pass. Do not set
`PHASE2_REQUIRE_REAL_DOMAINS=false`, `PHASE2_REQUIRE_SMTP=false`, or
`PHASE2_REQUIRE_OIDC_ENV=false` for a full-pass gate.

Server-only prerequisites:

- `ROOT_DOMAIN`, `AUTH_DOMAIN`, `HULY_DOMAIN`, `FILES_DOMAIN`, and `HF_DOMAIN`
  use the approved real domains, not `*.example.*`.
- School DNS resolves each public hostname to the staging/public IP.
- School TLS certificate and private key are installed under
  `/opt/lab-stack/certs`; private key mode is `0600` or stricter.
- SMTP host, port, username, password, and from address are real and validated.
- `AUTHENTIK_PHASE2_OIDC_APPS=huly,minio,hf-ui`.
- `AUTHENTIK_CHECK_DISCOVERY_SLUGS=huly,minio,hf-ui`.
- Huly, MinIO, and HF UI OIDC client IDs, client secrets, and HTTPS redirect
  URIs are set only in `/opt/lab-stack/env/20-authentik.env`.

Command sequence:

```bash
bash -n deploy/scripts/10-check-edge.sh \
  deploy/scripts/20-check-authentik.sh \
  deploy/scripts/19-check-phase2-preflight.sh \
  deploy/scripts/22-bootstrap-authentik-oidc.sh \
  deploy/scripts/lib/common.sh

git diff --check

sudo /opt/lab-stack/scripts/19-check-phase2-preflight.sh
sudo /opt/lab-stack/scripts/04-check-core.sh
sudo /opt/lab-stack/scripts/02-bootstrap-postgres.sh
sudo docker exec nginx nginx -t
sudo /opt/lab-stack/scripts/10-check-edge.sh
sudo /opt/lab-stack/scripts/22-bootstrap-authentik-oidc.sh
sudo /opt/lab-stack/scripts/20-check-authentik.sh

curl -Ik "http://$AUTH_DOMAIN/"
curl -ksSfL "https://$AUTH_DOMAIN/api/v3/root/config/" >/dev/null
curl -ksSfL "https://$AUTH_DOMAIN/application/o/huly/.well-known/openid-configuration" >/dev/null
curl -ksSfL "https://$AUTH_DOMAIN/application/o/minio/.well-known/openid-configuration" >/dev/null
curl -ksSfL "https://$AUTH_DOMAIN/application/o/hf-ui/.well-known/openid-configuration" >/dev/null

openssl s_client -connect "$AUTH_DOMAIN:443" -servername "$AUTH_DOMAIN" </dev/null
ss -tulpn | awk 'NR > 1 {print $5}' | sed 's/.*://' | sort -n | uniq
```

Expected strict full-pass results:

- `19-check-phase2-preflight.sh` exits `0` without relaxed flags.
- Domains are real and DNS-backed.
- TLS chain validates with the school certificate.
- SMTP env is real and browser SMTP test mail is received.
- Authentik root config and all three OIDC discovery URLs are reachable over
  HTTPS.
- Public app exposure is limited to approved ports. Nginx publishes 80/443;
  Postgres, Redis, and Authentik do not publish direct host ports.

## Authentik Browser Evidence Template

Create browser evidence without exposing credentials. Use screenshots only after
checking that no secret values, tokens, setup URLs, passwords, recovery codes, or
private email contents are visible.

```text
Evidence timestamp:
Operator:
Hostnames:
Browser/profile:

Admin 2FA:
- Action: log in as admin from a private browser session.
- Expected: second factor is required before dashboard access.
- Result:
- Evidence file or note:

Invitation-only enrollment:
- Action: create a one-time invitation/enrollment link for a test user.
- Expected: invited user can enroll and reaches the expected group.
- Result:
- Evidence file or note:

Self-signup blocked:
- Action: attempt enrollment without invitation from a private browser session.
- Expected: signup is denied or no public enrollment flow is available.
- Result:
- Evidence file or note:

SMTP test:
- Action: send Authentik test mail and trigger an enrollment/admin notification.
- Expected: mail is received at the operator mailbox.
- Result:
- Evidence file or note:

Group claims:
- Action: complete OIDC login for a test user and inspect claims through an
  approved non-secret debug view or application session.
- Expected: `groups` contains the correct Authentik group, such as `lab-member`;
  MinIO policy mapping is present when testing MinIO.
- Result:
- Evidence file or note:

OIDC clients:
- Action: review Authentik applications/providers for `huly`, `minio`, and
  `hf-ui`.
- Expected: confidential clients, strict HTTPS redirect URIs, expected scopes,
  per-provider issuer URLs, and active-user policy binding.
- Result:
- Evidence file or note:
```

## Pass, Fail, and Stop Criteria

Pass:

- Exposed GitHub token is revoked or rotated, and sudo password is rotated.
- Secret scans have no real or ambiguous unhandled secrets.
- PR remains draft until strict checks and browser evidence are complete.
- Strict Phase 2 commands pass without relaxed flags.
- Real DNS, school TLS, real SMTP, OIDC discovery, group checks, admin 2FA,
  invitation-only enrollment, self-signup block, and browser evidence all pass.
- Reports and PR text record only redacted evidence.

Conditional-pass:

- Container-level checks pass but any full-pass dependency is missing, including
  real DNS, school TLS, real SMTP, manual Authentik evidence, or required secret
  rotations. This is the current staging state and must not be represented as
  operational full-pass.

Fail:

- A required script exits non-zero, an OIDC discovery URL is unreachable, SMTP
  does not send, TLS does not validate, unexpected public ports are exposed, or
  Authentik browser security controls do not behave as required.

Stop:

- Any real or ambiguous secret is found in git-facing surfaces.
- The exposed GitHub token or sudo password has not been rotated.
- A command requires relaxed Phase 2 flags to pass.
- DNS points to the wrong host, TLS private key permissions exceed `0600`, or
  a private key appears outside approved server-only paths.
- PR contents would include unrelated worker edits, real secrets, or evidence
  screenshots containing sensitive values.
