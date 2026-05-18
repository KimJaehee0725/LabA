# Experiment 0016 - Revalidate Phase 2-6 staging readiness after PR #2

Date: 2026-05-11 07:33 +0000
Status: conditional-pass
Tags: -

## Goal

Confirm the Overleaf branch still passes relaxed staging checks while documenting that strict full-pass remains pending.

## Setup

Ran local static checks and relaxed /opt/lab-stack checks with Huly, MinIO, HF UI, and Overleaf enabled; sub-agents inspected Security/Edge/Auth, Huly/Ops, Storage/HF UI, and Overleaf readiness without editing files.

## Metrics

- 80-check-overleaf.sh passes; relaxed integrated 96-check-all.sh reaches and passes all included phases; full-pass blockers are documented.

## Results

Passed for relaxed staging on 2026-05-11. Strict full-pass remains blocked by deferred credential rotation/waiver, real DNS/TLS/SMTP, browser evidence, and minimal ops evidence.

## Artifacts

- deploy/runbooks/full-pass-readiness.md
- deploy/reports/phase6-overleaf.md

## Interpretation / Next

Keep PR #2 draft, complete real DNS/TLS/SMTP and browser evidence, then rerun strict checks without relaxed flags.
