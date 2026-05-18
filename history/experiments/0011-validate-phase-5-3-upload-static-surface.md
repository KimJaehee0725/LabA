# Experiment 0011 - Validate Phase 5.3 upload static surface

Date: 2026-05-10 19:14 +0000
Status: passed
Tags: -

## Goal

Phase 5.3 upload 변경이 runtime redeploy 전 정적 검증에서 API/UI/script 계약 오류 없이 통과하는지 확인한다.

## Setup

main.py py_compile, app.js node syntax check, shell bash -n, env example을 source한 docker compose config, Docker build, 빌드된 이미지 안의 FastAPI TestClient upload presign 계약 검사, git diff whitespace check를 실행했다.

## Metrics

- 명령 exit code, compose config 렌더링 성공 여부, upload presign API 상태 코드/응답 계약.

## Results

모든 정적 검증과 in-image API 계약 검사가 통과했다. API 검사는 새 upload presign 성공, duplicate upload HTTP 409, invalid upload path HTTP 400, 기존 download presign 호환성을 확인했다. /opt/lab-stack 접근 권한이 없어 실제 presigned PUT staging smoke는 보류했다.

## Artifacts

- deploy/hf-ui/app/main.py; deploy/hf-ui/app/static/app.js; deploy/scripts/44-check-hf-ui.sh

## Interpretation / Next

서버에서 hf-ui를 rebuild/restart하고 43-bootstrap-hf-ui-storage.sh, 44-check-hf-ui.sh를 실행해 presigned PUT과 CORS preflight를 확인한다.
