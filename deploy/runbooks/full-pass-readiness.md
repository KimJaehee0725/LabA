# Full-Pass Readiness Overview

Status: Phase 2-6 conditional smoke/staging pass; Phase 7 internal operational
baseline pass; Phase 8 MLflow internal staging validation pass; operational
full-pass pending.

This overview coordinates the evidence required before the Huly workspace MVP is
promoted from staging conditional-pass to operational full-pass. Use it after
the Phase 2-8 staging/internal reports pass and before marking the draft PR
ready.

## Read First

- `full-pass-security-edge-auth.md`: credential safety, draft PR checks, real
  DNS/TLS/SMTP, Authentik browser evidence.
- `full-pass-huly-ops.md`: Huly browser OIDC, workspace seed, GitHub App,
  Google Calendar, Notion sample, timeline/Gantt, one-week pilot, minimal ops
  gate.
- `full-pass-storage-hf.md`: MinIO role evidence, HF UI browser smoke,
  upload/download/preview checks, CORS fallback and smoke object cleanup.
- `phase7-operational-baseline.md`: internal active-stack backup, isolated
  restore rehearsal, disk/cert/permission checks, service exposure checks, and
  repo-facing secret scan hygiene.
- `mlflow.md`: Phase 8 internal MLflow Tracking checks and Authentik-gated
  public route requirements.

## Current Blockers

- Real DNS and trusted TLS evidence are not available yet.
- SMTP is still placeholder-only in the staging environment.
- Browser OIDC evidence is missing for Authentik, Huly, MinIO, and HF UI.
- The exposed GitHub token and sudo password are intentionally deferred by the
  current operator policy, so strict full-pass and PR-ready promotion remain
  blocked until that policy changes or an explicit waiver is recorded.
- `HF_UI_ALLOW_STAGING_BYPASS=true` is acceptable only for staging automation
  and must be disabled before strict HF UI browser validation.
- Phase 6 Overleaf conditional smoke checks pass with relaxed real-domain and
  SMTP gates, including private admin activation, HTTP-session English/Korean
  compile, socket route smoke, and backup checksums. Invite mail,
  browser login/logout, browser collaboration, trusted TLS, real SMTP, and
  restore rehearsal evidence remain pending.
- Phase 7 internal operational baseline automation exists to close non-external
  ops evidence, and passed on `2026-05-12` with backup/restore evidence. It is
  not a substitute for strict full-pass.
- Phase 8 MLflow can pass internal service/API/artifact checks before public UI
  exposure. Public MLflow UI must remain disabled or Authentik-gated.

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
- Overleaf remains `conditional smoke passed / strict full-pass pending`:
  `80-check-overleaf.sh` and integrated relaxed `96-check-all.sh` passed on
  `2026-05-11` with relaxed real-domain and SMTP gates. Conditional admin
  activation, English/Korean compile, socket route, and backup checksum evidence
  were added later on `2026-05-11`, but browser login/logout, invite delivery,
  real SMTP, trusted TLS, two-browser collaboration, and restore rehearsal
  evidence remain incomplete. Admin creation must use `/overleaf`, and
  activation output must stay out of reports.
- PR #2 should stay draft under the current credential policy. It may be
  reviewed as a staging-only Overleaf PR, but must not be represented as
  operational full-pass.
- Phase 7 internal ops baseline passed on `2026-05-12`: active backup,
  isolated restore rehearsal, disk/cert/permission checks, active service
  exposure checks, and repo-facing high-risk secret scan completed. The
  unrelated `/workspace/LLM-API-Watcher` host process was moved from port `3000`
  to `3010`; the relaxed integrated `96-check-all.sh` with Phase 7 opt-in then
  passed on `2026-05-12T05:54:25Z`.

## Full-Pass Order

1. Rotate exposed credentials and rerun secret scans.
2. Replace example domains, install trusted TLS, and configure real SMTP.
3. Run Phase 2 strict Edge/Auth checks and capture Authentik browser evidence.
4. Run Phase 3 Huly strict checks and collect GitHub, Calendar, Notion,
   timeline/Gantt, and one-week pilot evidence.
5. Run Phase 4/5 strict MinIO and HF UI checks, then capture role/browser
   evidence for `lab-admin`, `lab-member`, `lab-collab`, and `lab-guest`.
6. Run Phase 8 MLflow internal checks if MLflow is in scope, and keep the public
   route disabled unless Authentik gate evidence is available.
7. Complete the Phase 7 internal ops gate: active backup, restore rehearsal,
   cert expiry, disk usage, permissions, service exposure, and secret scan
   evidence.
8. Update phase reports from conditional-pass to pass only when every blocker is
   resolved without relaxed flags, or explicitly record a scoped waiver with
   owner, date, and accepted risk.

## PR Gate

The current branch may remain a draft PR while the environment is still
staging-only. Do not mark it ready for review until:

- Secret scans have no unhandled real or ambiguous findings.
- Credential rotation is confirmed without recording replacement values.
- Local static checks pass.
- Staging `96-check-all.sh` still passes.
- Phase 7 internal operational baseline passes if PR text claims operational
  readiness below strict full-pass.
- Full-pass blockers are either resolved or explicitly scoped to a later PR.
- Phase 6 Overleaf conditional smoke is not enough for PR-ready full-pass
  claims until real DNS/TLS, real SMTP delivery, browser login/logout and
  collaboration smoke, and restore evidence are recorded without secrets.

## Evidence Rules

- Record timestamps, role, URL, command/action, result, and evidence filename.
- Do not record passwords, tokens, private keys, client secrets, session
  cookies, authorization codes, presigned URL query strings, or raw private
  research data.
- Store screenshots and browser artifacts outside git unless they are scrubbed
  and explicitly approved for publication.
- Reports may name server-only paths such as `/opt/lab-stack/env/*.env`, but not
  the values inside them.
- Overleaf reports must not include admin activation URLs, passwords, tokens,
  project Git credentials, private paper content, or raw private evidence
  values.
