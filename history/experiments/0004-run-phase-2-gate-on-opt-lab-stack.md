# Experiment 0004 - Run Phase 2 gate on /opt lab stack

Date: 2026-05-10 01:34 +0000
Status: conditional-pass
Tags: phase-2, edge-auth, opt-lab-stack

## Goal

sudo 가능한 세션에서 Phase 2 Edge/Auth 스택을 /opt/lab-stack runtime root로 전환하고 운영 full-pass 가능 여부를 확인한다.

## Setup

/opt/lab-stack에 tracked deploy tree를 복사하고 server-only env 값을 생성했다. 학교 DNS/TLS/SMTP 실값은 없어 self-signed certificate와 example domain placeholder로 조건부 실행했다.

## Metrics

- strict 19-check-phase2-preflight.sh, relaxed preflight, 04-check-core.sh, 10-check-edge.sh, 22-bootstrap-authentik-oidc.sh, 20-check-authentik.sh, 96-check-all.sh, HTTP redirect, Authentik root config, Docker health, OIDC apps/providers

## Results

conditional-pass: /opt/lab-stack bind mount로 postgres, redis, nginx, authentik-server, authentik-worker가 healthy이고 relaxed 96-check-all.sh와 OIDC discovery가 통과했다. strict preflight는 example domains, placeholder SMTP, placeholder redirect URIs 때문에 실패한다.

## Artifacts

- deploy/reports/phase2-edge-auth-staging.md
- deploy/runbooks/phase2-edge-auth.md

## Interpretation / Next

학교 DNS/TLS/SMTP와 production redirect URI를 /opt/lab-stack/env 및 cert paths에 반영한 뒤 strict preflight와 동일 게이트를 relaxed flags 없이 재실행한다.
