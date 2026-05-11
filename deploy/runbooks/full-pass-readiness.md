# Full-Pass Readiness Overview

Status: Phase 2-6 staging conditional-pass; operational full-pass pending.

This overview coordinates the evidence required before the Huly workspace MVP is
promoted from staging conditional-pass to operational full-pass. Use it after
the Phase 2-6 staging reports pass and before marking the draft PR ready.

## Read First

- `full-pass-security-edge-auth.md`: credential safety, draft PR checks, real
  DNS/TLS/SMTP, Authentik browser evidence.
- `full-pass-huly-ops.md`: Huly browser OIDC, workspace seed, GitHub App,
  Google Calendar, Notion sample, timeline/Gantt, one-week pilot, minimal ops
  gate.
- `full-pass-storage-hf.md`: MinIO role evidence, HF UI browser smoke,
  upload/download/preview checks, CORS fallback and smoke object cleanup.

## Current Blockers

- Real DNS and trusted TLS evidence are not available yet.
- SMTP is still placeholder-only in the staging environment.
- Browser OIDC evidence is missing for Authentik, Huly, MinIO, and HF UI.
- The exposed GitHub token and sudo password are intentionally deferred by the
  current operator policy, so strict full-pass and PR-ready promotion remain
  blocked until that policy changes or an explicit waiver is recorded.
- `HF_UI_ALLOW_STAGING_BYPASS=true` is acceptable only for staging automation
  and must be disabled before strict HF UI browser validation.
- Phase 6 Overleaf automated staging checks pass, but admin activation, invite
  mail, compile, collaboration/logout, trusted TLS, real SMTP, and
  backup/restore evidence remain pending.

## 2026-05-11 Verification Snapshot

- Security/Edge/Auth remains `conditional-pass`: strict Phase 2 still needs real
  DNS, trusted TLS, real SMTP, Authentik browser evidence, and credential
  rotation or a documented waiver.
- Huly/Pilot/Ops remains `conditional-pass`: browser OIDC, workspace seed,
  GitHub/Calendar roundtrips, Notion/timeline evidence, one-week pilot, and
  minimal ops evidence are pending.
- Storage/HF UI remains `conditional-pass`: strict real-domain checks, MinIO
  role evidence, HF UI browser OIDC/upload evidence, CORS evidence, and smoke
  retention/cleanup decision are pending.
- Overleaf remains `automated staging passed / manual full-pass pending`:
  `80-check-overleaf.sh` and integrated relaxed `96-check-all.sh` passed on
  `2026-05-11`, but browser/admin/SMTP/compile/collaboration/backup restore
  evidence is not complete.
- PR #2 should stay draft under the current credential policy. It may be
  reviewed as a staging-only Overleaf PR, but must not be represented as
  operational full-pass.

## Full-Pass Order

1. Rotate exposed credentials and rerun secret scans.
2. Replace example domains, install trusted TLS, and configure real SMTP.
3. Run Phase 2 strict Edge/Auth checks and capture Authentik browser evidence.
4. Run Phase 3 Huly strict checks and collect GitHub, Calendar, Notion,
   timeline/Gantt, and one-week pilot evidence.
5. Run Phase 4/5 strict MinIO and HF UI checks, then capture role/browser
   evidence for `lab-admin`, `lab-member`, `lab-collab`, and `lab-guest`.
6. Complete the minimal ops gate: backup, restore, cert expiry, disk usage, and
   uptime alert evidence.
7. Update phase reports from conditional-pass to pass only when every blocker is
   resolved without relaxed flags, or explicitly record a scoped waiver with
   owner, date, and accepted risk.

## PR Gate

The current branch may remain a draft PR while the environment is still
staging-only. Do not mark it ready for review until:

- Secret scans have no unhandled real or ambiguous findings.
- Credential rotation is confirmed without recording replacement values.
- Local static checks pass.
- Staging `96-check-all.sh` still passes.
- Full-pass blockers are either resolved or explicitly scoped to a later PR.

## Evidence Rules

- Record timestamps, role, URL, command/action, result, and evidence filename.
- Do not record passwords, tokens, private keys, client secrets, session
  cookies, authorization codes, presigned URL query strings, or raw private
  research data.
- Store screenshots and browser artifacts outside git unless they are scrubbed
  and explicitly approved for publication.
- Reports may name server-only paths such as `/opt/lab-stack/env/*.env`, but not
  the values inside them.
