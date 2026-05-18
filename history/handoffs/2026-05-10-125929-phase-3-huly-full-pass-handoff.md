# Handoff - Phase 3 Huly full-pass handoff

Date: 2026-05-10 12:59 +0000
To: next operator or subagent

Task: phase-3
Workstream: huly
Approval Status: accepted
Promoted To: -
Archived: no
Archived Date: -
## Summary

Huly core staging is deployed under /opt/lab-stack and passes relaxed integrated checks. GitHub and Google Calendar services are present but disabled because credentials are not available. The pilot report is conditional-pass and documents the evidence still needed for strict full pass.

## Ownership / Files

- deploy/runbooks/phase3-huly.md
- deploy/reports/phase3-huly-pilot.md
- deploy/env/30-huly.env.example

## Next Actions

Provide real domain and trusted TLS, configure SMTP, set HULY_OIDC_TLS_REJECT_UNAUTHORIZED=1, run browser OIDC login, execute workspace seed checklist, add GitHub App and Calendar credentials, enable profiles, validate integration routes, complete Notion sample import and one-week pilot, then run strict 96-check-all.

## Risks

Do not commit /opt/lab-stack/env/30-huly.env or any generated secrets. Current staging uses self-signed TLS and intentionally disabled optional integrations.
