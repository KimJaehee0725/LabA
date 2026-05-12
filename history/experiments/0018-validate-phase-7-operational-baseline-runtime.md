# Experiment 0018 - Validate Phase 7 operational baseline runtime

Date: 2026-05-12 05:46 +0000
Status: passed
Tags: -

## Goal

실제 /opt/lab-stack에서 active backup, restore rehearsal, ops baseline, post-backup Huly/Overleaf checks가 통과하는지 확인한다.

## Setup

Huly cold backup을 허용하고 /mnt/backup/lab/archive/phase7/2026-05-12/20260512T054224Z에 백업을 생성한 뒤 restore rehearsal과 ops baseline gate를 실행했다.

## Metrics

- manifest.tsv 16 lines; restore-rehearsal.tsv 8 lines; ops baseline passed with 12 strict-blocker warnings

## Results

Passed for internal operational baseline. Relaxed integrated 96-check-all.sh는 unrelated /workspace/LLM-API-Watcher process on public port 3000 때문에 10-check-edge.sh에서 중단됐다.

## Artifacts

- deploy/reports/phase7-operational-baseline.md

## Interpretation / Next

Clear or waive the unrelated port 3000 process before rerunning integrated 96-check-all.sh with Phase 7 opt-in.
