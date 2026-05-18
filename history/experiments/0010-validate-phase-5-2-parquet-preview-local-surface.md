# Experiment 0010 - Validate Phase 5.2 Parquet preview local surface

Date: 2026-05-10 18:52 +0000
Status: completed
Tags: -

## Goal

Parquet preview backend/UI/ops 변경을 staging 배포 전 로컬 정적, compose, container 수준에서 검증한다.

## Setup

Sub-agent 3개로 backend, UI, ops를 분리 구현한 뒤 main rollout에서 통합 검토와 Docker image 검증을 수행했다.

## Metrics

- JSONL/CSV/JSON 기존 preview 유지, Parquet rows/schema/source_type/numeric stats, Parquet range byte cap HTTP 413, shell/JS/Python syntax, compose config, Docker build

## Results

모든 로컬 검증이 통과했다. /opt/lab-stack는 현재 사용자에게 권한이 없고 passwordless sudo가 없어 Phase 5.2 staging redeploy와 /opt smoke는 pending이다.

## Artifacts

- lab/hf-ui:phase5.2-preview; deploy/reports/phase5-hf-ui.md

## Interpretation / Next

-
