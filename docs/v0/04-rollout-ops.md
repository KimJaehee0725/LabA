# 04. Rollout and Operations

## 구축 전략

한 번에 전체 플랫폼을 올리지 않는다. 각 단계는 다음 조건을 만족해야 다음 단계로 넘어간다.

- 컨테이너가 재시작 후에도 정상 기동
- Nginx 라우팅 정상
- 로그인 정상
- 파일 업로드 또는 핵심 write 동작 정상
- DB dump 가능
- restore 절차 초안 존재
- 로그에서 반복 에러 없음

## Phase 0. 준비

작업:

- 실제 서버 hostname, IP, 방화벽 확인
- `/srv/lab-platform` 생성
- git repo 초기화 또는 원격 연결
- `.env.example` 작성
- `.gitignore` 작성
- Docker network 생성 계획 확정

완료 기준:

- secret이 git에 들어가지 않는 구조 확인
- root/sudo 작업 절차 확인
- 백업 저장 위치와 권한 확인

## Phase 1. Core

작업:

- `lab_public`, `lab_backend`, `lab_data` 네트워크 생성
- Postgres 기동
- Redis 기동
- MinIO 기동
- Nginx placeholder 기동
- DB/user/bucket bootstrap script 작성

검증:

```bash
docker network ls
docker compose ps
docker exec postgres pg_isready
docker exec redis redis-cli ping
```

완료 기준:

- 외부에서 보이는 포트가 의도한 포트뿐임
- Postgres/Redis/MinIO가 host에 직접 bind되지 않음
- DB dump 테스트 성공

## Phase 2. Authentik

작업:

- Authentik server/worker 기동
- admin 생성
- 그룹 blueprint 적용
- MFA flow 적용
- SMTP 설정
- OIDC test application 생성

검증:

- admin 로그인
- 일반 사용자 생성
- MFA enrollment
- email 발송 테스트
- blueprint 재적용 테스트

완료 기준:

- `lab-admin`, `lab-member`, `lab-collab`, `lab-guest` 그룹 존재
- MFA 적용 확인
- admin fallback 계정 안전하게 보관

## Phase 3. Gitea

작업:

- Gitea 기동
- Postgres 연결
- MinIO LFS 연결
- Authentik OIDC 연결
- SSH 포트 정책 결정
- 초기 organization 생성

검증:

- OIDC 로그인
- repo 생성
- git clone/push
- LFS upload/download
- backup dump

완료 기준:

- 일반 registration 비활성화
- private repo 기본 정책 확인
- LFS가 MinIO bucket으로 저장됨

## Phase 4. Plane

작업:

- 공식 self-host compose 기준으로 서비스 구성
- 내장 DB/Redis/MinIO 제거
- 외부 core 연결
- Authentik OIDC 연결

검증:

- workspace 생성
- OIDC 로그인
- issue/work item 생성
- file upload
- worker/beat 로그 확인

완료 기준:

- 핵심 협업 흐름 동작
- 첨부 파일이 MinIO bucket에 저장됨

## Phase 5. MLflow

작업:

- MLflow server 구성
- Postgres backend store 연결
- MinIO artifact store 연결
- Authentik Forward Auth 구성
- 학습 노드 접근 방식 결정

검증:

- 브라우저 UI 접근 시 Authentik login
- experiment 생성
- metric log
- artifact upload
- model registration

완료 기준:

- 인증 없이 MLflow UI 접근 불가
- artifact가 `mlflow-artifacts` bucket에 저장됨

## Phase 6. Nextcloud + Collabora

작업:

- Nextcloud 기동
- 필수 앱 설치
- Authentik OIDC 연결
- Collabora 연결
- group folders 생성
- cron 확인

검증:

- OIDC login
- 파일 업로드/download
- docx 생성 및 Collabora 편집
- calendar/contacts 앱 확인
- WebDAV app password 테스트

완료 기준:

- Background job이 cron으로 동작
- 큰 파일 업로드 제한과 PHP 설정 확인
- 백업 절차 테스트

## Phase 7. Overleaf CE

작업:

- Overleaf, MongoDB, Redis 기동
- admin 생성
- SMTP 확인
- TeX Live 패키지 전략 결정
- Gitea backup workflow 문서화

검증:

- admin activation
- 사용자 초대
- LaTeX compile
- 한글 문서 compile
- project git export/push

완료 기준:

- 사용자 생성/초대 흐름 확정
- 프로젝트 백업 절차 문서화

## 백업 정책

최소 백업 대상:

| 대상 | 백업 방식 |
|---|---|
| Postgres | DB별 `pg_dump` 또는 전체 dump |
| MinIO | bucket replication 또는 `mc mirror` |
| Gitea git data | Gitea dump + volume backup |
| Nextcloud data | maintenance mode + data volume + DB |
| Overleaf MongoDB | `mongodump` |
| Authentik blueprints/media/certs | file backup |
| split env files | 암호화된 별도 보관 |
| Nginx/Auth configs | git + backup |

권장 retention 초안:

| 주기 | 보관 기간 |
|---|---|
| daily | 14일 |
| weekly | 8주 |
| monthly | 12개월 |

오프사이트 백업은 구현 전 결정 필요다.

## Restore drill

서비스별 첫 운영 전 최소 1회 restore drill을 한다.

1. DB dump 생성
2. 임시 DB에 restore
3. 앱이 임시 DB로 기동 가능한지 확인
4. 파일/object storage 경로 일치 확인
5. restore 절차 문서 업데이트

## 업데이트 정책

원칙:

- 한 번에 전체 플랫폼 업데이트 금지
- 서비스별 업데이트
- 업데이트 전 백업
- minor update도 release note 확인
- major update는 테스트 compose에서 먼저 확인
- image tag는 명시 버전 사용

업데이트 절차:

```bash
cd /srv/lab-platform/compose/<service>
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/<module>.env \
  pull
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/<module>.env \
  up -d
docker compose ps
docker logs --tail=200 <container>
```

core 의존성이 필요한 모듈은 `10-core.env`도 함께 지정한다. 정확한 env 조합은 v0.1의 env 운영 문서에서 모듈별로 확정한다.

## 운영 로그

각 단계마다 다음을 `docs/ops-log/` 또는 Gitea issue에 남긴다.

- 변경 날짜
- 변경자
- 변경 서비스
- image tag
- 적용 명령
- 검증 결과
- rollback 방법
- 남은 문제

## 모니터링 v0

v0는 가벼운 점검으로 시작한다.

- `docker compose ps`
- Nginx access/error log
- 서비스별 health endpoint
- 디스크 사용량
- MinIO bucket 용량
- Postgres dump 성공 여부

후속으로 Prometheus/Grafana/Loki를 검토한다.
