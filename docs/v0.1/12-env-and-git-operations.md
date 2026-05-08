# 12. Env and Git Operations

## 목표

v0.2부터 실제 compose와 script가 만들어지면 환경변수와 git 작업 단위가 빠르게 커진다. 이 문서는 env 파일을 과도하게 거대하게 만들지 않고, 변경 시점마다 commit/branch/worktree를 어떻게 쓸지 정한다.

## Env 관리 원칙

1. 실제 secret은 git에 넣지 않는다.
2. repo에는 example 파일과 변수 설명만 둔다.
3. 운영 서버의 실제 env는 `/srv/lab-platform/env/` 아래에 분할한다.
4. compose 실행 시 여러 env 파일을 명시적으로 합성한다.
5. 공통 변수와 서비스별 변수를 분리한다.
6. secret rotation이 필요한 값을 한 파일에 과도하게 몰아넣지 않는다.

## 운영 서버 env 구조

운영 서버 기준:

```text
/srv/lab-platform/
├── env/
│   ├── 00-global.env
│   ├── 10-core.env
│   ├── 20-authentik.env
│   ├── 30-gitea.env
│   ├── 40-plane.env
│   ├── 50-mlflow.env
│   ├── 60-nextcloud.env
│   ├── 70-overleaf.env
│   ├── 80-minio-policies.env
│   └── 90-backup.env
└── compose/
```

권한:

```bash
chown -R root:lab-ops /srv/lab-platform/env
chmod 0750 /srv/lab-platform/env
chmod 0640 /srv/lab-platform/env/*.env
```

`lab-ops` 그룹은 실제 운영자 그룹 이름으로 바꿀 수 있다. 단일 운영자만 있으면 `root:root`와 `0600`도 가능하다.

## Repo example 구조

repo 기준:

```text
deploy/env/
├── README.md
├── 00-global.env.example
├── 10-core.env.example
├── 20-authentik.env.example
├── 30-gitea.env.example
├── 40-plane.env.example
├── 50-mlflow.env.example
├── 60-nextcloud.env.example
├── 70-overleaf.env.example
├── 80-minio-policies.env.example
└── 90-backup.env.example
```

실제 `.env` 파일은 `.gitignore`로 제외한다.

## Env 파일 역할

| 파일 | 역할 | 예시 변수 |
|---|---|---|
| `00-global.env` | 도메인, 경로, 공통 timezone | `LAB_PLATFORM_ROOT`, `ROOT_DOMAIN`, `TZ` |
| `10-core.env` | Postgres, Redis, MinIO root/bootstrap | `POSTGRES_PASSWORD`, `REDIS_PASSWORD`, `MINIO_ROOT_USER` |
| `20-authentik.env` | Authentik secret, DB, SMTP, bootstrap | `AUTHENTIK_SECRET_KEY`, `AUTHENTIK_BOOTSTRAP_PASSWORD` |
| `30-gitea.env` | Gitea DB, OIDC, internal tokens | `GITEA_DB_PASSWORD`, `GITEA_SECRET_KEY` |
| `40-plane.env` | Plane DB/Redis/S3/OIDC | `PLANE_DB_PASSWORD`, `PLANE_OIDC_CLIENT_SECRET` |
| `50-mlflow.env` | MLflow DB/S3/outpost | `MLFLOW_DB_PASSWORD`, `MLFLOW_S3_ACCESS_KEY` |
| `60-nextcloud.env` | Nextcloud DB/admin/OIDC | `NEXTCLOUD_ADMIN_PASSWORD`, `NEXTCLOUD_OIDC_CLIENT_SECRET` |
| `70-overleaf.env` | Overleaf admin/SMTP/Mongo | `OVERLEAF_ADMIN_EMAIL`, `OVERLEAF_MONGO_PASSWORD` |
| `80-minio-policies.env` | service access keys | `GITEA_LFS_ACCESS_KEY`, `MLFLOW_S3_SECRET_KEY` |
| `90-backup.env` | backup target/retention | `BACKUP_RETENTION_DAILY`, `BACKUP_REMOTE_TARGET` |

## Compose 실행 방식

각 모듈은 필요한 env 파일만 명시한다.

예:

```bash
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  -f /srv/lab-platform/compose/core/docker-compose.yml \
  up -d
```

Plane 예:

```bash
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  --env-file /srv/lab-platform/env/40-plane.env \
  -f /srv/lab-platform/compose/plane/docker-compose.yml \
  up -d
```

주의:

- Docker Compose는 뒤쪽 `--env-file` 값이 앞쪽 값을 덮어쓸 수 있다.
- 같은 변수명을 여러 파일에서 정의하지 않는 것을 원칙으로 한다.
- 공통 변수는 `00-global.env`, secret은 각 서비스 파일에 둔다.

## Secret rotation 단위

분할 env의 목적은 rotation blast radius를 줄이는 것이다.

| 변경 | 재시작 대상 |
|---|---|
| `GITEA_OIDC_CLIENT_SECRET` | Gitea |
| `PLANE_OIDC_CLIENT_SECRET` | Plane |
| `MLFLOW_S3_SECRET_KEY` | MLflow |
| `AUTHENTIK_SECRET_KEY` | Authentik, 신중히 |
| `REDIS_PASSWORD` | Redis와 Redis 사용 서비스 전체 |
| `POSTGRES_PASSWORD` | Postgres bootstrap/admin 계정, 신중히 |

## Git 운영 원칙

### Commit 단위

다음 시점마다 commit한다.

- 문서 단계 완료
- deploy skeleton 생성 완료
- core compose가 `docker compose config` 통과
- Nginx skeleton이 `nginx -t` 통과
- Authentik이 기동하고 blueprint 적용 완료
- 서비스별 module smoke 통과
- backup/check script가 dry-run 통과

Commit message 형식:

```text
docs: add v0.1 module planning
deploy: add core compose skeleton
auth: add authentik blueprints
ops: add backup dry-run scripts
```

### Branch 전략

기본:

- `main`: 검증된 문서/구현 baseline
- `feature/v0.2-core`
- `feature/v0.2-authentik`
- `feature/v0.2-gitea`
- `feature/v0.2-plane`
- `feature/v0.2-mlflow`
- `feature/v0.2-nextcloud`
- `feature/v0.2-overleaf`
- `feature/v0.2-ops`

작업이 작으면 같은 branch에서 진행할 수 있지만, 서비스별 compose와 script가 충돌할 가능성이 있으면 branch를 나눈다.

### Worktree 전략

worktree는 다음 경우에만 쓴다.

- 한 서비스 구현 중 다른 서비스 hotfix가 필요할 때
- 긴 작업을 유지한 채 smoke fix를 별도 검증할 때
- v0.2 구현과 v0.3 smoke report를 병렬로 작성할 때

예:

```bash
git worktree add ../LabA-v0.2-core -b feature/v0.2-core
git worktree add ../LabA-v0.2-auth -b feature/v0.2-authentik
```

정리:

```bash
git worktree list
git worktree remove ../LabA-v0.2-core
git branch -d feature/v0.2-core
```

### Merge 원칙

merge 전 확인:

- `git status --short`
- 관련 문서 검증
- compose config 또는 script dry-run
- history 기록 갱신

merge 방식:

- 작은 문서 변경은 fast-forward 가능
- 서비스 구현 branch는 `--no-ff` merge도 허용
- 충돌이 잦은 파일은 먼저 모듈별로 분리한다.

## History 기록 원칙

다음에는 `history/`에 기록한다.

- 아키텍처 결정
- 보안 관련 결정
- 실제 compose/script 추가
- service smoke 결과
- 실패한 접근과 rollback
- branch/worktree/merge handoff

기록 금지:

- secret 값
- token 값
- private key
- 개인 비밀번호

## v0.2 반영 사항

v0.2 Epic A에 추가한다.

- `deploy/env/README.md`
- split env example files
- `.gitignore` secret patterns
- compose helper script 또는 runbook에 multi `--env-file` 명령

