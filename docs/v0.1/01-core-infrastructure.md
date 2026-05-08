# 01. Core Infrastructure Module

## 모듈 목표

Core module은 모든 서비스가 공유할 운영 기반을 만든다.

포함:

- 디렉토리 구조
- split env example files
- Docker networks
- Postgres
- Redis
- MinIO
- bootstrap scripts
- 공통 compose conventions

제외:

- 서비스별 app compose
- Nginx server block 상세
- Authentik blueprints
- backup full automation

## 입력 전제

- Ubuntu host
- Docker와 Docker Compose v2 설치됨
- root 또는 sudo 가능
- 기본 경로: `/srv/lab-platform`
- 실제 도메인은 아직 placeholder

## v0.2 산출물

repo:

```text
deploy/env/README.md
deploy/env/00-global.env.example
deploy/env/10-core.env.example
deploy/compose/core/docker-compose.yml
deploy/scripts/00-create-directories.sh
deploy/scripts/01-create-networks.sh
deploy/scripts/02-bootstrap-postgres.sh
deploy/scripts/03-bootstrap-minio.sh
deploy/scripts/04-check-core.sh
deploy/runbooks/core.md
```

server:

```text
/srv/lab-platform/env/00-global.env
/srv/lab-platform/env/10-core.env
/srv/lab-platform/data/postgres
/srv/lab-platform/data/redis
/srv/lab-platform/data/minio
/srv/lab-platform/logs
/srv/lab-platform/backups
```

## 디렉토리 계획

초기 생성:

```bash
install -d -m 0750 /srv/lab-platform
install -d -m 0750 /srv/lab-platform/compose
install -d -m 0750 /srv/lab-platform/data
install -d -m 0750 /srv/lab-platform/logs
install -d -m 0750 /srv/lab-platform/backups/archive
install -d -m 0750 /srv/lab-platform/backups/scripts
install -d -m 0750 /srv/lab-platform/nginx/conf.d
install -d -m 0750 /srv/lab-platform/nginx/snippets
install -d -m 0700 /srv/lab-platform/nginx/ssl
```

env 권한:

```bash
install -d -m 0750 /srv/lab-platform/env
chown -R root:lab-ops /srv/lab-platform/env
chmod 0640 /srv/lab-platform/env/*.env
```

단일 운영자 환경이면 `root:root`와 `0600`으로 더 강하게 제한한다.

## Docker network 계획

```bash
docker network create lab_public
docker network create lab_backend
docker network create lab_data
```

정책:

- `lab_public`: host port를 받는 edge only
- `lab_backend`: Nginx와 app web/API
- `lab_data`: app backend와 Postgres/Redis/MinIO

Compose 파일에서는 network를 external로 참조한다.

## Compose convention

공통:

- 모든 compose는 `/srv/lab-platform/env/*.env`를 모듈별로 합성해 실행한다.
- 프로젝트 이름은 명시한다.
- container name은 운영 편의상 명시하되, 중복 위험을 피한다.
- image tag는 고정한다.
- `restart: unless-stopped` 사용.
- host port publish는 core edge 또는 Gitea SSH 외 금지.

예상 실행 형태:

```bash
cd /srv/lab-platform/compose/core
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  up -d
```

## Postgres 계획

역할:

- Authentik
- Plane
- Gitea
- MLflow
- Nextcloud

DB/user:

| DB | User | 용도 |
|---|---|---|
| `authentik` | `authentik_user` | Authentik |
| `plane` | `plane_user` | Plane |
| `gitea` | `gitea_user` | Gitea |
| `mlflow` | `mlflow_user` | MLflow |
| `nextcloud` | `nextcloud_user` | Nextcloud |

v0.2 bootstrap script:

- superuser password는 `/srv/lab-platform/env/10-core.env`에서 읽음
- DB가 없으면 생성
- role이 없으면 생성
- 각 DB owner 지정
- `public` schema 권한 점검

검증:

```bash
docker exec postgres pg_isready
docker exec postgres psql -U "$POSTGRES_USER" -c '\l'
```

## Redis 계획

역할:

- Authentik cache/broker
- Plane queue/cache
- Nextcloud file locking/cache 후보

DB index:

| Redis DB | 용도 |
|---:|---|
| 0 | Authentik |
| 1 | reserved |
| 2 | Plane |
| 3 | Nextcloud |

정책:

- Redis password 필수.
- host port publish 금지.
- DB index는 운영 편의 분리일 뿐 보안 경계가 아니다.
- 문제가 생기면 서비스별 Redis 분리를 후속으로 검토한다.

검증:

```bash
docker exec redis redis-cli -a "$REDIS_PASSWORD" ping
```

## MinIO 계획

역할:

- Plane uploads
- Gitea LFS
- MLflow artifacts
- 선택적으로 backups 또는 Nextcloud primary

Buckets:

| Bucket | Owner module |
|---|---|
| `plane-uploads` | Plane |
| `gitea-lfs` | Gitea |
| `mlflow-artifacts` | MLflow |
| `backups` | optional |
| `nextcloud-primary` | optional, v0.2 기본 제외 |

정책:

- root user는 bootstrap과 emergency admin만.
- 앱에는 root credential을 주지 않는다.
- 서비스별 access key 또는 policy를 생성한다.
- MinIO API는 `lab_data` 내부에서만 접근한다.
- Console은 Nginx를 통과하고 Authentik OIDC를 붙일 수 있도록 계획한다.

v0.2 bootstrap script:

- alias 설정
- bucket 생성
- versioning 여부 결정
- service policy 생성
- service access key 생성

주의:

- service access key 생성 결과는 secret이므로 stdout에 그대로 남기지 않는다.
- 초기에는 policy 파일 template만 repo에 두고 실제 key는 서버 `/srv/lab-platform/env/80-minio-policies.env`에 기록한다.

## split env example 주요 항목

`deploy/env/00-global.env.example`:

```dotenv
LAB_PLATFORM_ROOT=/srv/lab-platform
ROOT_DOMAIN=lab.snu.ac.kr
AUTH_DOMAIN=auth.lab.snu.ac.kr
GITEA_DOMAIN=hub.lab.snu.ac.kr
PLANE_DOMAIN=lab.snu.ac.kr
MLFLOW_DOMAIN=mlflow.lab.snu.ac.kr
NEXTCLOUD_DOMAIN=files.lab.snu.ac.kr
COLLABORA_DOMAIN=office.lab.snu.ac.kr
OVERLEAF_DOMAIN=papers.lab.snu.ac.kr
MINIO_CONSOLE_DOMAIN=storage.lab.snu.ac.kr
TZ=Etc/UTC
```

`deploy/env/10-core.env.example`:

```dotenv
POSTGRES_IMAGE=postgres:16
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=change-me

REDIS_IMAGE=redis:7
REDIS_PASSWORD=change-me

MINIO_IMAGE=minio/minio:REPLACE_WITH_PINNED_VERSION
MINIO_ROOT_USER=change-me
MINIO_ROOT_PASSWORD=change-me
MINIO_REGION=ap-northeast-2

PLANE_DB_NAME=plane
GITEA_DB_NAME=gitea
MLFLOW_DB_NAME=mlflow
NEXTCLOUD_DB_NAME=nextcloud
AUTHENTIK_DB_NAME=authentik
```

실제 v0.2에서는 image tag를 구현 시점에 공식 문서와 registry에서 확인해 고정한다.

전체 env 분할 정책은 [12-env-and-git-operations.md](./12-env-and-git-operations.md)에 둔다.

## 검증 기준

Core 완료 조건:

- `docker compose config` 성공
- `docker compose up -d` 성공
- Postgres/Redis/MinIO가 running
- host open port에 Postgres/Redis/MinIO가 없음
- DB/user 목록 확인됨
- MinIO bucket 생성됨
- backup directory 쓰기 가능

## 실패 시 rollback

초기 구축 단계 rollback:

```bash
cd /srv/lab-platform/compose/core
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/10-core.env \
  down
```

데이터 삭제는 별도 명령으로 분리한다. `down -v`는 사용하지 않는다.

## 남은 결정

- Postgres image major version
- Redis image major version
- MinIO image tag
- MinIO service account 자동 생성 방식
- backup bucket을 MinIO 내부에 둘지 외부에 둘지
