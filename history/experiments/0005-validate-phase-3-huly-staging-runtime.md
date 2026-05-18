# Experiment 0005 - Validate Phase 3 Huly staging runtime

Date: 2026-05-10 12:59 +0000
Status: conditional-pass
Tags: phase3, huly, staging

## Goal

Confirm Huly core can run behind the Phase 2 edge/auth baseline without direct host ports.

## Setup

Copied Phase 3 files to /opt/lab-stack, generated local staging env without recording secrets, bootstrapped Authentik OIDC, started Huly core compose, and recreated Nginx so the new Huly route was mounted.

## Metrics

- Preflight result, Huly container health/running state, no host ports, HTTPS front response, OIDC callback route, Authentik discovery, seed artifact check, pilot-report marker check, and relaxed full-stack check-all.

## Results

conditional-pass: Huly front returned HTTP 200 via Nginx, OIDC callback route reached account service with HTTP 405, Authentik Huly discovery returned HTTP 200, Huly core containers run without host ports, relaxed /opt check-all passed with GitHub/Calendar/pilot strict gates disabled.

## Artifacts

- deploy/reports/phase3-huly-pilot.md

## Interpretation / Next

Replace staging placeholders with real DNS/TLS/SMTP, set HULY_OIDC_TLS_REJECT_UNAUTHORIZED=1, complete browser OIDC login, seed workspace, enable GitHub and Calendar integrations, import Notion sample, collect one-week pilot evidence, then run strict Phase 3 checks.
