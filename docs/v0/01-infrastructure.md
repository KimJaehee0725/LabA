# 01. Infrastructure

## 기본 경로

v0 기본 경로는 다음으로 둔다.

```text
/srv/lab-platform
```

경로는 바뀔 수 있으므로 구현 파일에서는 가능하면 `LAB_PLATFORM_ROOT` 같은 변수를 둔다. 단, 운영 스크립트와 문서는 `/srv/lab-platform` 기준으로 작성한다.

## 디렉토리 구조

```text
/srv/lab-platform/
├── .env
├── .env.example
├── compose/
│   ├── core/
│   ├── authentik/
│   ├── plane/
│   ├── gitea/
│   ├── mlflow/
│   ├── nextcloud/
│   └── overleaf/
├── nginx/
│   ├── conf.d/
│   ├── snippets/
│   └── ssl/
├── data/
│   ├── postgres/
│   ├── redis/
│   ├── minio/
│   ├── authentik/
│   ├── gitea/
│   ├── nextcloud/
│   ├── overleaf/
│   └── mlflow/
├── backups/
│   ├── scripts/
│   └── archive/
└── logs/
```

원칙:

- compose 파일과 운영 데이터는 분리한다.
- v0.1부터 실제 secret은 `/srv/lab-platform/env/*.env`로 분할한다.
- 백업 산출물은 `/srv/lab-platform/backups/archive` 아래 날짜별로 둔다.

## Docker 네트워크

v0 기본 네트워크:

| 네트워크 | 용도 | 외부 연결 |
|---|---|---|
| `lab_public` | Nginx가 host port와 연결되는 경계 | Nginx만 |
| `lab_backend` | Nginx와 앱 web/API 간 통신 | 외부 bind 없음 |
| `lab_data` | 앱 backend와 DB/Redis/MinIO 통신 | 외부 bind 없음 |

예상 네트워크 연결:

| 컨테이너 | `lab_public` | `lab_backend` | `lab_data` |
|---|---:|---:|---:|
| nginx | yes | yes | no |
| postgres | no | no | yes |
| redis | no | no | yes |
| minio | no | backend는 console/API 경유 시 제한 | yes |
| authentik-server | no | yes | yes |
| authentik-worker | no | no | yes |
| plane-web/admin/space | no | yes | no |
| plane-api/worker/beat | no | yes | yes |
| gitea | no | yes | yes |
| mlflow | no | yes | yes |
| nextcloud | no | yes | yes |
| collabora | no | yes | no |
| overleaf | no | yes | 자체 mongo/redis |

## 포트 정책

Host에 bind 가능한 포트:

| 포트 | 용도 | 조건 |
|---:|---|---|
| 80 | HTTP -> HTTPS redirect | 공개 가능 |
| 443 | HTTPS | 공개 가능 |
| 2222 | Gitea SSH | Git over SSH가 필요할 때만 공개 |

Host에 bind하면 안 되는 포트:

- Postgres `5432`
- Redis `6379`
- MinIO API `9000`
- MinIO Console `9001`
- Authentik internal ports
- 앱별 web/API internal ports
- Outpost metrics ports

MinIO Console을 외부에서 써야 하면 Nginx를 통해 `storage.<domain>`으로만 노출하고, Authentik/OIDC 또는 강한 admin 정책으로 보호한다.

## Core 스택

core compose의 책임:

- Docker network 생성 또는 external network 참조
- Postgres
- Redis
- MinIO
- Nginx
- backup runner 또는 backup script 위치 제공

core 스택은 앱보다 먼저 올라와야 한다.

## DB/User/Bucket 설계

각 서비스별 DB와 user를 분리한다.

| 서비스 | DB | DB user | MinIO bucket |
|---|---|---|---|
| Authentik | `authentik` | `authentik_user` | none |
| Plane | `plane` | `plane_user` | `plane-uploads` |
| Gitea | `gitea` | `gitea_user` | `gitea-lfs` |
| MLflow | `mlflow` | `mlflow_user` | `mlflow-artifacts` |
| Nextcloud | `nextcloud` | `nextcloud_user` | 결정 필요 |

Postgres superuser는 bootstrap과 backup에만 사용한다. 앱은 자기 DB user로만 접속한다.

Redis는 하나의 인스턴스를 쓰되 DB index를 분리한다.

| Redis DB | 용도 |
|---:|---|
| 0 | Authentik |
| 1 | reserved |
| 2 | Plane |
| 3 | Nextcloud lock/cache 후보 |
| 4 | reserved |

Redis DB index 분리만으로 보안 격리가 강해지는 것은 아니므로, 민감한 멀티테넌트 격리가 필요해지면 Redis 인스턴스 분리를 검토한다.

## 환경변수와 secret

v0 초기안은 단일 `.env`였지만, v0.1에서 split env로 정리한다.

파일:

```text
/srv/lab-platform/env/00-global.env
/srv/lab-platform/env/10-core.env
/srv/lab-platform/env/<service>.env
deploy/env/*.env.example
```

권한:

```bash
chown -R root:lab-ops /srv/lab-platform/env
chmod 0750 /srv/lab-platform/env
chmod 0640 /srv/lab-platform/env/*.env
```

원칙:

- 실제 `*.env`는 git에 넣지 않는다.
- `*.env.example`에는 placeholder만 둔다.
- OAuth client secret, DB password, SMTP password, MinIO root password, Authentik secret key는 모두 랜덤 생성한다.
- secret 회전 절차를 운영 문서에 둔다.

## Nginx 원칙

Nginx는 단일 외부 진입점이다.

공통 snippet 후보:

- `proxy-params.conf`
- `ssl-params.conf`
- `security-headers.conf`
- `upload-large.conf`
- `websocket.conf`

기본 정책:

- HTTP는 HTTPS로 redirect
- `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Real-IP` 설정
- WebSocket이 필요한 서비스는 별도 snippet 적용
- 업로드 크기는 서비스별로 제한
- 관리자 경로는 가능하면 추가 allowlist 또는 Authentik policy 적용

## TLS

도메인이 확정되기 전까지는 TLS 발급 방식을 결정하지 않는다.

후보:

| 방식 | 장점 | 단점 |
|---|---|---|
| Let's Encrypt HTTP-01 | 단순 | 외부에서 80 접근 가능해야 함 |
| Let's Encrypt DNS-01 | 내부망/프록시 환경에 유리 | DNS provider API 필요 |
| 학교/기관 인증서 | 조직 정책에 맞음 | 발급/갱신 절차 의존 |
| Cloudflare origin cert | Cloudflare 사용 시 편함 | Cloudflare 경유 전제 |

v0에서는 `nginx/ssl/origin.crt`, `origin.key` 경로만 예약하고, 실제 방식은 도메인 확정 후 결정한다.
