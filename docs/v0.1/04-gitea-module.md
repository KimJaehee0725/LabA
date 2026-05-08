# 04. Gitea Module

## 모듈 목표

Gitea는 연구실 Git hosting, 모델/데이터셋 LFS 저장소, 논문 부속 저장소 역할을 한다.

포함:

- Gitea compose
- Postgres 연동
- MinIO LFS 연동
- Authentik OIDC 로그인
- SSH port `2222`
- 초기 organization
- backup/dump 절차

## 공식 문서 반영사항

Gitea 공식 config cheat sheet는 LFS와 attachment storage에 `minio` storage type을 사용할 수 있음을 설명한다. OAuth2 client 설정에는 auto registration, username source, account linking 같은 보안 영향 옵션이 있다. 공식 authentication 문서는 관리자 UI에서 Authentication Source를 추가하는 흐름을 안내한다.

v0.1 결정:

- LFS는 MinIO bucket `gitea-lfs`.
- 일반 registration은 비활성화.
- OIDC auto registration은 Authentik group/email 정책 확인 후 활성화.

## v0.2 산출물

```text
deploy/compose/gitea/docker-compose.yml
deploy/gitea/app.ini.template
deploy/nginx/conf.d/30-gitea.conf
deploy/scripts/40-bootstrap-gitea.sh
deploy/scripts/41-check-gitea.sh
deploy/runbooks/gitea.md
```

## 의존성

- Postgres DB: `gitea`
- MinIO bucket: `gitea-lfs`
- Authentik OIDC provider: `gitea`
- Nginx: `hub.lab.snu.ac.kr`
- optional host port: `2222/tcp`

## 데이터 구조

```text
/srv/lab-platform/data/gitea/
├── data/
│   ├── git/
│   ├── gitea/
│   └── ssh/
└── config/
```

실제 Gitea container path는 image 기준에 맞춰 조정한다.

## app.ini 계획

핵심 섹션:

```ini
[server]
DOMAIN = hub.lab.snu.ac.kr
ROOT_URL = https://hub.lab.snu.ac.kr/
SSH_DOMAIN = hub.lab.snu.ac.kr
SSH_PORT = 2222
START_SSH_SERVER = true
LFS_START_SERVER = true

[database]
DB_TYPE = postgres
HOST = postgres:5432
NAME = gitea
USER = gitea_user
PASSWD = ${GITEA_DB_PASSWORD}

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = false

[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
USERNAME = email
UPDATE_AVATAR = true
ACCOUNT_LINKING = auto

[lfs]
STORAGE_TYPE = minio
```

`ACCOUNT_LINKING=auto`는 email 신뢰가 전제다. v0.2에서 위험하면 `login`으로 시작하고 운영자가 수동 연결한다.

## Secret 생성

필요:

- `SECRET_KEY`
- `INTERNAL_TOKEN`
- `LFS_JWT_SECRET`

생성:

```bash
docker run --rm gitea/gitea:<tag> gitea generate secret SECRET_KEY
docker run --rm gitea/gitea:<tag> gitea generate secret INTERNAL_TOKEN
docker run --rm gitea/gitea:<tag> gitea generate secret LFS_JWT_SECRET
```

값은 `/srv/lab-platform/env/30-gitea.env`에만 저장한다.

## OIDC 설정

Authentik:

- Provider: `gitea-provider`
- Client ID: `gitea`
- Redirect URI: `https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback`

Gitea:

- Authentication Source: OAuth2
- Provider: OpenID Connect
- Discovery URL: `https://auth.lab.snu.ac.kr/application/o/gitea/.well-known/openid-configuration`
- Skip local 2FA: yes, Authentik MFA 사용

## Organization 계획

초기:

| Org | 용도 | Visibility |
|---|---|---|
| `lab-code` | 코드 | private |
| `lab-models` | 모델 weight/metadata | private |
| `lab-datasets` | 데이터셋 | private |
| `lab-papers` | 논문 부속 | private |

권한:

- `lab-admin`: owner
- `lab-member`: 필요 org별 write
- `lab-collab`: repo별 초대
- `lab-guest`: 기본 없음

## SSH 계획

외부 포트:

```text
hub.lab.snu.ac.kr:2222
```

검증:

```bash
ssh -T -p 2222 git@hub.lab.snu.ac.kr
```

주의:

- HTTP Git clone은 Nginx 경유.
- SSH는 Gitea container 또는 built-in SSH server로 직접 publish.
- 방화벽에서 `2222`만 허용한다.

## LFS 계획

대상:

```text
*.safetensors
*.bin
*.ckpt
*.pt
*.onnx
*.parquet
```

검증:

1. test repo 생성
2. `git lfs track "*.bin"`
3. 큰 dummy file push
4. MinIO `gitea-lfs` bucket object 확인
5. clone 후 LFS pull 확인

## 백업

대상:

- Postgres `gitea`
- Gitea data/git volume
- Gitea config
- MinIO `gitea-lfs`

권장:

```bash
docker exec -u git gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/gitea-dump.zip
```

MinIO LFS는 별도 bucket backup이 필요하다.

## 검증 기준

Gitea 완료 조건:

- OIDC 로그인
- local admin fallback 존재
- repo 생성
- SSH push
- HTTPS clone
- LFS push/pull
- organization 생성
- registration disabled
- dump 생성

## 위험

| 위험 | 대응 |
|---|---|
| Auto registration으로 원치 않는 사용자 생성 | Authentik group policy, Gitea registration 제한 |
| LFS가 로컬에 저장됨 | app.ini와 MinIO bucket object 확인 |
| SSH host key/port 문제 | runbook에 host key와 firewall 절차 명시 |
| 대용량 push timeout | Nginx upload/proxy buffering 설정 |
