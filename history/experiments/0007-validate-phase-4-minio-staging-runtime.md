# Experiment 0007 - Validate Phase 4 MinIO staging runtime

Date: 2026-05-10 14:00 +0000
Status: conditional-pass
Tags: -

## Goal

Run Phase 4 shared MinIO on /opt/lab-stack and verify bucket, policy, public/private S3 behavior, and backup smoke.

## Setup

Synced Phase 4 files to /opt/lab-stack, created 35-minio-storage.env, preserved existing secrets, bootstrapped Authentik OIDC, mounted the staging TLS cert into MinIO CA trust, loaded 30-minio-storage.conf in Nginx, and recreated Nginx to pick up nginx.conf.

## Metrics

- 33/34/35 scripts and LABSTACK_INCLUDE_MINIO=true 96-check-all.sh exit status.

## Results

Conditional pass: shared minio is running healthy with no host ports; bucket/versioning/policy bootstrap passed; private anonymous access returned HTTP 403; lab-public anonymous download passed; backup mirror checksum/size matched. Full pass still requires real DNS/TLS and browser OIDC role evidence.

## Artifacts

- deploy/reports/phase4-minio-storage.md

## Interpretation / Next

Complete browser checks for files.lab.example.ac.kr with lab-member and lab-guest after production DNS/TLS are ready.
