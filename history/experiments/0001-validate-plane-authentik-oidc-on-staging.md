# Experiment 0001 - Validate Plane Authentik OIDC on staging

Date: 2026-05-08 19:01 +0000
Status: completed
Tags: plane, oidc, staging

## Goal

Plane v0.25.0 custom OIDC backend/web images must pass staging runtime smoke checks with Authentik.

## Setup

Used temporary env files under /tmp reconstructed from running container env without printing secrets; deployed local custom Plane compose to lab_plane; Authentik provider/application bootstrapped with client secret redacted.

## Metrics

- Discovery check, custom image startup, migration, /api/instances OIDC flags, /auth/oidc/ Authentik authorize redirect, browser-visible login button, MinIO anonymous-denied and bucket checks.

## Results

Passed after adding quoted env values, OIDC_VERIFY_SSL=0 for self-signed staging TLS, and updating the Plane check to expect Authentik /application/o/authorize/. Running plane-api/worker/beat and plane-web now use lab-plane-*:v0.25.0-authentik-oidc images. Headless Chromium confirmed the Plane login screen shows Continue with Authentik and clicking it reaches the Authentik authentication flow.

## Artifacts

- deploy/scripts/51-check-plane.sh
- deploy/compose/plane/custom/patches/plane-authentik-oidc.patch

## Interpretation / Next

Persist real /srv/lab-platform/env/40-plane.env values with sudo/root: PLANE_OIDC_DISCOVERY_URL, quoted PLANE_OIDC_SCOPES, PLANE_OIDC_VERIFY_SSL=0 until trusted TLS is installed, and OIDC provider label/client secret.
