# Experiment 0015 - Validate Phase 6 Overleaf staging checks

Date: 2026-05-10 20:26 +0000
Status: passed
Tags: -

## Goal

Verify the Overleaf direct Compose module can run beside Huly, MinIO, and HF UI without changing existing runtime paths when enabled conditionally.

## Setup

Built and recreated Overleaf on /opt/lab-stack, initialized the Mongo replica set, ran the Phase 6 check, then ran 96-check-all.sh with Huly, MinIO, HF UI, and Overleaf enabled using staging relaxations for example domains, SMTP, GitHub, Calendar, and manual pilot full-pass evidence.

## Metrics

- 80-check-overleaf.sh passes; conditional 96-check-all.sh reaches and passes 80-check-overleaf.sh.

## Results

Passed. Phase 6 check completed at 2026-05-10T20:22:41Z and conditional 96-check-all.sh completed through Overleaf at 2026-05-10T20:24:42Z.

## Artifacts

- deploy/reports/phase6-overleaf.md

## Interpretation / Next

Complete manual browser smoke for admin activation, English and Korean compile, collaboration/logout, then rerun full pass with real DNS/TLS/SMTP and strict pilot evidence.
