# Experiment 0008 - Validate Phase 5 HF-like UI staging runtime

Date: 2026-05-10 17:52 +0000
Status: conditional-pass
Tags: -

## Goal

HF-like UI가 Phase 4 MinIO 객체와 YAML catalog를 사용해 모델/데이터셋 목록, 상세, 파일 트리, presigned download를 staging HTTPS 경로에서 처리하는지 확인한다.

## Setup

/opt/lab-stack에 Phase 5 app/compose/env/nginx/scripts를 배포하고 HF_UI_ALLOW_STAGING_BYPASS=true, STAGING_IP=127.0.0.1, PHASE5_REQUIRE_REAL_DOMAINS=false로 검증했다. Secret 값은 기록하지 않았다.

## Metrics

- Container health, no host ports, /api/health, index HTTP status, Authentik OIDC discovery, catalog counts, model detail/README, file tree, presigned S3 URL domain, download success, integrated 96-check-all exit code.

## Results

44-check-hf-ui.sh passed at 2026-05-10T17:50Z. 96-check-all.sh with LABSTACK_INCLUDE_MINIO=true and LABSTACK_INCLUDE_HF_UI=true exited 0 at 2026-05-10T17:51Z. Result is conditional-pass because real DNS/TLS and browser OIDC evidence are still pending.

## Artifacts

- deploy/reports/phase5-hf-ui.md

## Interpretation / Next

When real domains are available, disable staging bypass, run strict /opt/lab-stack/scripts/44-check-hf-ui.sh, then capture lab-member and lab-guest browser OIDC evidence.
