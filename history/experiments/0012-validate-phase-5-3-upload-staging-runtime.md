# Experiment 0012 - Validate Phase 5.3 upload staging runtime

Date: 2026-05-10 19:25 +0000
Status: passed
Tags: -

## Goal

Phase 5.3 HF UI upload v1이 /opt/lab-stack staging runtime에서 MinIO CORS, presigned PUT, preview 연동까지 통과하는지 확인한다.

## Setup

업데이트된 HF UI app/compose/scripts/report를 /opt/lab-stack에 동기화하고, lab/hf-ui:phase5를 rebuild/recreate한 뒤 43-bootstrap-hf-ui-storage.sh, 44-check-hf-ui.sh, 96-check-all.sh를 실행했다.

## Metrics

- 스크립트 exit code, CORS preflight PUT 허용, direct PUT 성공, uploaded JSONL preview 성공, duplicate upload HTTP 409.

## Results

통과. bucket-level CORS는 현재 MinIO runtime에서 NotImplemented였고, bootstrap의 global api cors_allow_origin fallback이 적용된 상태에서 44-check-hf-ui.sh와 96-check-all.sh가 exit 0으로 통과했다.

## Artifacts

- /opt/lab-stack/reports/phase5-hf-ui.md

## Interpretation / Next

Real DNS/TLS와 browser OIDC evidence가 준비되면 strict mode에서 browser upload smoke를 캡처한다.
