# Experiment 0006 - Validate Phase 4 MinIO storage static surface

Date: 2026-05-10 13:35 +0000
Status: conditional-pass
Tags: -

## Goal

Run static evidence for Phase 4 MinIO before root-owned /opt/lab-stack staging execution.

## Setup

Checked shell syntax, compose rendering with deploy/env examples sourced, DRY_RUN bucket/policy bootstrap, git diff whitespace, and common token/private-key patterns.

## Metrics

- Command exit status and absence of credible secret-scan hits.

## Results

Static validation passed. /opt/lab-stack staging commands were not executed because the runtime tree is root:root 0750 and sudo requires a password in this shell.

## Artifacts

- deploy/reports/phase4-minio-storage.md

## Interpretation / Next

Run /opt/lab-stack/scripts/33-bootstrap-minio-storage.sh, 34-check-minio-storage.sh, 35-check-minio-backup-smoke.sh, and LABSTACK_INCLUDE_MINIO=true 96-check-all.sh from a root-capable shell.
