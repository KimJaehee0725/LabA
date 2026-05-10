# Experiment 0003 - Phase 2 Edge/Auth local staging validation

Date: 2026-05-10 01:00 +0000
Status: conditional-pass
Tags: phase-2, edge-auth, staging

## Goal

Phase 2 Edge/Auth 계획을 실제 Docker 런타임에서 검증하고 다음 Phase 3 전제 조건을 분리한다.

## Setup

passwordless sudo가 없어 /opt/lab-stack 대신 LAB_STACK_ROOT=/tmp/lab-stack-phase2, ENV_DIR=/tmp/lab-stack-phase2/env로 core, edge, authentik compose 스택을 검증했다.

## Metrics

- 04-check-core.sh, 10-check-edge.sh, 20-check-authentik.sh, Nginx config test, HTTP->HTTPS redirect, Authentik root config endpoint, Docker health, published ports, staging certificate metadata

## Results

conditional-pass: postgres, redis, nginx, authentik-server, authentik-worker가 healthy/running이고 자동 게이트는 통과했다. /opt/lab-stack live-root 실행, 실제 DNS/SSL/SMTP, admin 2FA, invitation enrollment, OAuth provider/client secret 생성은 운영 세션에서 남아 있다.

## Artifacts

- deploy/reports/phase2-edge-auth-staging.md

## Interpretation / Next

sudo 가능한 운영 세션에서 /opt/lab-stack로 동일 runbook을 재실행하고, 실제 인증서/SMTP/2FA/invitation/OIDC provider를 검증한 뒤 Phase 3 Huly OIDC 연결로 넘어간다.
