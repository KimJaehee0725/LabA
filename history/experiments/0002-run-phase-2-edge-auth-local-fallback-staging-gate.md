# Experiment 0002 - Run Phase 2 Edge/Auth local fallback staging gate

Date: 2026-05-10 00:59 +0000
Status: completed
Tags: phase2, edge-auth, staging

## Goal

Validate the Phase 2 Edge/Auth staging baseline after implementation.

## Setup

Passwordless sudo was unavailable, so ran with LAB_STACK_ROOT=/tmp/lab-stack-phase2, generated server-only env values under /tmp, and used --resolve to reach auth.lab.example.ac.kr on 127.0.0.1.

## Metrics

- Core Postgres/Redis check, Nginx config and redirect, Authentik root config endpoint, Authentik group check, Docker network attachment, public port scan.

## Results

Conditional pass: Postgres/Redis, Nginx, and Authentik became healthy; HTTP redirects to HTTPS; Authentik root config returned 200; lab groups passed. Initial Authentik startup exposed a bind-mount ownership issue, fixed in 00-create-directories.sh with Authentik UID/GID chown.

## Artifacts

- deploy/reports/phase2-edge-auth-staging.md
- deploy/runbooks/phase2-edge-auth.md

## Interpretation / Next

Live /opt/lab-stack execution still needs sudo and manual Authentik 2FA/enrollment/SMTP/OIDC provider setup before full Phase 2 pass.
