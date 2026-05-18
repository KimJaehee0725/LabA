# Experiment 0019 - Validate Phase 8 MLflow runtime

Date: 2026-05-15 05:38 +0000
Status: pass
Tags: phase8

## Goal

Confirm MLflow can run on the active stack, create a smoke run, persist artifacts to shared MinIO, and participate in backup/restore rehearsal.

## Setup

/opt/lab-stack with shared Postgres, shared MinIO, Nginx, Huly, HF UI, and Overleaf already running. MLflow public route disabled; PHASE8_REQUIRE_AUTH_GATE=false for internal mode.

## Metrics

- 60-check-mlflow.sh result; relaxed 96-check-all result; backup manifest and restore rehearsal entries.

## Results

Passed on 2026-05-15. MLflow check passed at 05:37:51Z, relaxed integrated 96-check-all passed at 05:34:37Z, backup/restore with LABSTACK_BACKUP_MLFLOW=true passed under /mnt/backup/lab/archive/phase7/2026-05-15/20260515T053501Z.

## Artifacts

- deploy/reports/phase8-mlflow.md

## Interpretation / Next

Keep public MLflow route disabled until Authentik outpost/forward-auth values exist; then run PHASE8_REQUIRE_AUTH_GATE=true edge check.
