# Experiment 0017 - Complete Overleaf conditional smoke

Date: 2026-05-11 09:04 +0000
Status: passed
Tags: -

## Goal

Finish Phase 6 conditional admin, compile, socket, and backup evidence without recording secrets.

## Setup

Created and privately activated the Overleaf admin, created English and Korean smoke projects, fixed runtime TeX packages, and ran backup evidence collection.

## Metrics

- users=1 admins=1 projects=2 docs=2
- English and Korean compile returned success with output.pdf
- socket route HTTP 200
- backup checksums recorded in deploy/reports/phase6-overleaf.md

## Results

Passed conditionally; strict DNS/TLS/SMTP/browser collaboration/restore evidence remains pending.

## Artifacts

- deploy/reports/phase6-overleaf.md

## Interpretation / Next

Run strict full-pass after real DNS/TLS/SMTP and browser evidence are available.
