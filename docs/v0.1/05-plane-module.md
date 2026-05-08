# 05. Plane Module

## 모듈 목표

Plane은 연구실 프로젝트, 이슈, 위키, 일정의 메인 협업 공간이다.

포함:

- Plane compose
- 외부 Postgres/Redis/MinIO 치환
- Authentik OIDC
- Nginx routing
- upload 검증
- worker/beat 검증

## 공식 문서 반영사항

Plane 공식 self-hosting 문서는 Docker 기반 배포를 제공한다. Plane은 버전별 compose와 환경변수 변화 가능성이 있으므로, v0.2에서는 공식 compose를 기준으로 가져오고 내장 DB/Redis/MinIO를 제거하는 방식으로 관리한다.

v0.1 결정:

- 직접 처음부터 compose를 완전히 쓰지 않는다.
- 공식 install script 또는 공식 compose를 기준으로 patch한다.
- 외부 core Postgres/Redis/MinIO 사용을 원칙으로 한다.

## v0.2 산출물

```text
deploy/compose/plane/docker-compose.yml
deploy/compose/plane/README.patch-notes.md
deploy/nginx/conf.d/20-plane.conf
deploy/scripts/50-bootstrap-plane.sh
deploy/scripts/51-check-plane.sh
deploy/runbooks/plane.md
```

## 의존성

- Postgres DB: `plane`
- Redis DB: `2`
- MinIO bucket: `plane-uploads`
- Authentik OIDC provider: `plane`
- Nginx: `lab.snu.ac.kr`

## 공식 compose patch 계획

제거:

- built-in Postgres
- built-in Redis
- built-in MinIO

추가/수정:

- external networks: `lab_backend`, `lab_data`
- `DATABASE_URL`
- `REDIS_URL`
- `AWS_S3_ENDPOINT_URL`
- `AWS_S3_BUCKET_NAME`
- `WEB_URL`
- Authentik OIDC custom patch image 설정

서비스 네트워크 기준:

| Plane service | Network |
|---|---|
| web | `lab_backend` |
| space | `lab_backend` |
| admin | `lab_backend` |
| api | `lab_backend`, `lab_data` |
| worker | `lab_data` |
| beat | `lab_data` |

실제 서비스명은 공식 compose 확인 후 반영한다.

## Env 계획

```dotenv
PLANE_DOMAIN=lab.snu.ac.kr
PLANE_WEB_URL=https://lab.snu.ac.kr
PLANE_DB_NAME=plane
PLANE_DB_USER=plane_user
PLANE_DB_PASSWORD=change-me
PLANE_REDIS_DB=2
PLANE_S3_BUCKET=plane-uploads
PLANE_S3_ENDPOINT=http://minio:9000
PLANE_OIDC_DISCOVERY_URL=https://auth.lab.snu.ac.kr/application/o/plane/.well-known/openid-configuration
PLANE_OIDC_CLIENT_ID=plane
PLANE_OIDC_CLIENT_SECRET=change-me-after-authentik-provider
PLANE_OIDC_SCOPES="openid email profile groups"
PLANE_OIDC_VERIFY_SSL=1
PLANE_OIDC_PROVIDER_LABEL=Authentik
```

## OIDC 계획

Authentik:

- Provider/Application slug: `plane`
- Client ID: `plane`
- Redirect URIs:
  - `https://lab.snu.ac.kr/auth/oidc/callback/`

Plane:

- v0.25.0 custom backend/web image에서 `/auth/oidc/`와 로그인 버튼을 제공
- local email/password login은 v0.3 break-glass로 유지

검증:

- login button 노출
- Authentik redirect
- callback 후 workspace 진입
- group claim이 필요한 경우 token 확인

## MinIO upload 검증

절차:

1. Plane에서 work item 생성
2. 작은 파일 첨부
3. 큰 파일 첨부
4. MinIO `plane-uploads` bucket object 확인
5. 다운로드 확인

## Worker/beat 검증

확인:

- worker 로그에 Redis 연결 오류 없음
- beat 로그에 schedule 오류 없음
- API migration 완료 로그
- background job 처리 확인

## 백업

대상:

- Postgres `plane`
- MinIO `plane-uploads`
- Plane compose/env 설정

백업 검증:

- DB dump 성공
- bucket object listing 가능
- restore procedure 초안 존재

## v0.3 Smoke

- Authentik OIDC로 로그인
- workspace 생성 또는 접근
- project 생성
- work item 생성
- wiki/page 생성
- 파일 첨부
- worker/beat running

## 위험

| 위험 | 대응 |
|---|---|
| 공식 compose 업데이트로 env 변화 | patch-notes와 공식 compose diff 절차 유지 |
| OIDC callback path 불일치 | 두 redirect URI 모두 등록하고 실제 로그 확인 |
| MinIO credential root 공유 | Plane 전용 access key/policy 사용 |
| worker가 queue 처리 실패 | Redis DB index와 URL 검증 |
