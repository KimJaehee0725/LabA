# Experiment 0009 - Validate Phase 5.1 dataset preview static surface

Date: 2026-05-10 18:25 +0000
Status: completed
Tags: -

## Goal

Preview API와 static UI 변경을 staging 재배포 전 문법/compose/build 수준에서 검증한다.

## Setup

Python compile, bash syntax checks, compose config with example env, JS syntax check, Docker build, and in-image preview helper assertions.

## Metrics

- jsonl text/categorical stats, csv numeric stats, json schema/rows assertions

## Results

모든 로컬 정적 검증과 preview helper assertion이 통과했다. /opt/lab-stack는 현재 사용자에게 권한이 없어 staging 재배포와 /opt smoke 실행은 수행하지 못했다.

## Artifacts

- deploy/hf-ui/app/main.py; deploy/scripts/44-check-hf-ui.sh

## Interpretation / Next

-
