# 04. Gitea

모델·데이터셋 레지스트리 (HF Hub 대체) + 일반 Git 호스팅.

## 공식 자료

- 문서: https://docs.gitea.com/
- LFS 가이드: https://docs.gitea.com/usage/git-lfs-support

## LFS 백엔드 결정

### 옵션 1: 로컬 디스크

```yaml
GITEA__server__LFS_START_SERVER: "true"
GITEA__lfs__PATH: /data/git/lfs
```

**장점**: 단순  
**단점**: 디스크 용량 직접 관리, 백업 시 큰 파일 매번 복사

### 옵션 2: MinIO (권장)

```yaml
GITEA__lfs__STORAGE_TYPE: minio
GITEA__lfs__SERVE_DIRECT: "false"
GITEA__lfs__MINIO_ENDPOINT: minio:9000
GITEA__lfs__MINIO_ACCESS_KEY_ID: ${MINIO_ROOT_USER}
GITEA__lfs__MINIO_SECRET_ACCESS_KEY: ${MINIO_ROOT_PASSWORD}
GITEA__lfs__MINIO_BUCKET: gitea-lfs
GITEA__lfs__MINIO_LOCATION: ${MINIO_REGION}
GITEA__lfs__MINIO_USE_SSL: "false"
```

**장점**: 백업 단일 위치, 디스크 확장 유연  
**단점**: 초기 설정 약간 복잡

연구실 모델 weight은 GB~수십GB 단위라 **MinIO 권장**.

## 첨부: app.ini 직접 설정 (선택)

환경변수 대신 `app.ini`로 관리하면 더 명시적:

```ini
# /srv/lab-platform/gitea/data/gitea/conf/app.ini
[server]
DOMAIN = hub.lab.snu.ac.kr
ROOT_URL = https://hub.lab.snu.ac.kr
SSH_DOMAIN = hub.lab.snu.ac.kr
SSH_PORT = 2222
LFS_START_SERVER = true
LFS_JWT_SECRET = ...
LFS_MAX_FILE_SIZE = 53687091200

[database]
DB_TYPE = postgres
HOST = postgres:5432
NAME = gitea
USER = gitea_user
PASSWD = ...

[lfs]
STORAGE_TYPE = minio
MINIO_ENDPOINT = minio:9000
MINIO_BUCKET = gitea-lfs
...

[service]
DISABLE_REGISTRATION = true
ENABLE_NOTIFY_MAIL = true
REQUIRE_SIGNIN_VIEW = false

[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
USERNAME = email
UPDATE_AVATAR = true
ACCOUNT_LINKING = auto

[security]
INSTALL_LOCK = true
SECRET_KEY = ...
INTERNAL_TOKEN = ...
```

`SECRET_KEY`, `INTERNAL_TOKEN`, `LFS_JWT_SECRET`는:
```bash
docker run --rm gitea/gitea:1.22 gitea generate secret SECRET_KEY
docker run --rm gitea/gitea:1.22 gitea generate secret INTERNAL_TOKEN
docker run --rm gitea/gitea:1.22 gitea generate secret LFS_JWT_SECRET
```

## Authentik OAuth2 연동

### 1단계: Authentik에서 설정 (이미 02-authentik.md에 있음)

확인할 것:
- Provider name: `gitea-provider`
- Client ID: `gitea`
- Redirect URI: `https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback`

### 2단계: Gitea에 OAuth2 추가

UI: Site Administration > Authentication Sources > Add Source

| 필드 | 값 |
|---|---|
| Authentication Type | OAuth2 |
| Authentication Name | `authentik` |
| OAuth2 Provider | OpenID Connect |
| Client ID | `gitea` |
| Client Secret | (Authentik에서 복사) |
| OpenID Connect Auto Discovery URL | `https://auth.lab.snu.ac.kr/application/o/gitea/.well-known/openid-configuration` |
| Skip Local 2FA | Yes (Authentik이 MFA 처리) |

저장하면 로그인 페이지에 "Sign in with authentik" 버튼 추가됨.

### 3단계: 자동 가입 활성화

`app.ini`에 다음 확인:
```ini
[oauth2_client]
ENABLE_AUTO_REGISTRATION = true
USERNAME = email          # 또는 preferred_username
ACCOUNT_LINKING = auto    # 기존 이메일과 자동 연결
```

이러면 Authentik으로 로그인하는 사용자가 자동으로 Gitea 계정 생성됨.

## Organization 구조

연구실 표준:

```
lab-models/          # 학습된 모델
├── qwen-grpo-base
├── qwen-grpo-bsr-v1
└── llama3-finetune

lab-datasets/        # 데이터셋
├── math-rl-prompts
├── code-eval-bench
└── eval-questions

lab-code/            # 일반 코드
├── grpo-trainer
├── eval-harness
└── data-pipeline

lab-papers/          # 논문 부속 (선택)
└── neurips-2026-grpo
```

생성:
```bash
# UI에서 또는 CLI로
docker exec -u git gitea gitea admin organization create --name lab-models --visibility private
```

## SSH 키 등록 (학습 노드)

학습 노드에서:
```bash
# 키 생성 (이미 있으면 skip)
ssh-keygen -t ed25519 -C "lab-node-1@snu.ac.kr"

# 공개키 복사
cat ~/.ssh/id_ed25519.pub
```

Gitea UI > Settings > SSH/GPG Keys > Add Key 에 붙여넣기.

테스트:
```bash
ssh -T -p 2222 git@hub.lab.snu.ac.kr
# Hi <username>! You've successfully authenticated...
```

## 모델 푸시 워크플로우

```bash
# 새 모델 리포 생성 (UI에서, lab-models org)
# 또는 API:
curl -X POST -u <user>:<pat> \
  https://hub.lab.snu.ac.kr/api/v1/orgs/lab-models/repos \
  -H "Content-Type: application/json" \
  -d '{"name": "qwen-grpo-bsr-v1", "private": true}'

# 학습 노드에서
git clone git@hub.lab.snu.ac.kr:2222/lab-models/qwen-grpo-bsr-v1.git
cd qwen-grpo-bsr-v1

git lfs install
git lfs track "*.safetensors"
git lfs track "*.bin"
git lfs track "*.ckpt"
git lfs track "*.pt"

# 모델 파일 복사
cp -r ~/training-output/checkpoint-1000/* .

# 메타데이터 README 작성
cat > README.md <<EOF
# Qwen 2.5 Math 7B - GRPO with BSR

## Training Config
- Base: Qwen/Qwen2.5-Math-7B
- Method: GRPO + Belief-Shift Reward (coef=0.5)
- Steps: 1000
- Reward Mean: 0.92

## Reproduction
See \`config.yaml\` and MLflow run: <mlflow-run-url>
EOF

git add .
git commit -m "Initial release: BSR coef=0.5"
git push origin main
```

## 모델 다운로드

```bash
# 학습 노드 또는 추론 노드
git lfs install  # 한 번만
git clone git@hub.lab.snu.ac.kr:2222/lab-models/qwen-grpo-bsr-v1.git

# 또는 특정 파일만
git clone --filter=blob:none --no-checkout ...
git sparse-checkout set "config.yaml" "tokenizer.json"
```

## API 사용 예시

```python
# Python으로 Gitea API
import requests

base = "https://hub.lab.snu.ac.kr/api/v1"
headers = {"Authorization": f"token {os.environ['GITEA_TOKEN']}"}

# 리포 목록
r = requests.get(f"{base}/orgs/lab-models/repos", headers=headers)
for repo in r.json():
    print(repo["name"], repo["size"], "KB")

# 새 리포 생성
requests.post(
    f"{base}/orgs/lab-models/repos",
    headers=headers,
    json={"name": "new-model", "private": True}
)
```

## Webhook (Plane / Slack 연동)

리포의 Settings > Webhooks > Add Webhook:

- Slack용: Slack incoming webhook URL
- Plane용: Plane이 GitHub webhook 호환 → Gitea의 GitHub 형식 webhook 사용

## 백업 항목

| 데이터 | 위치 |
|---|---|
| DB | postgres `gitea` DB |
| Git 저장소 | `/srv/lab-platform/gitea/data/git/` |
| LFS | MinIO `gitea-lfs` 버킷 (또는 로컬) |
| 설정 | `app.ini`, `.env` |

```bash
# Gitea 자체 dump 도구 (권장)
docker exec -u git gitea gitea dump -c /data/gitea/conf/app.ini -f /tmp/dump.zip
docker cp gitea:/tmp/dump.zip /srv/lab-platform/backups/archive/daily/$(date +%Y-%m-%d)/gitea-dump.zip
```

## 트러블슈팅

**LFS 업로드 시 timeout**:
- Nginx `client_max_body_size 50G` 확인
- `proxy_request_buffering off` 확인
- 큰 파일은 SSH 사용 (`git push` over SSH)

**SSH push 안 됨**:
- 호스트 키 등록: `ssh-keygen -t rsa -f /srv/lab-platform/gitea/data/ssh/gitea.host_key`
- UFW 2222 포트 허용 확인
- `docker logs gitea | grep ssh`

**MinIO LFS 사용 시 "object not found"**:
- 버킷 정책 확인: `docker exec minio mc anonymous get local/gitea-lfs`
- `MINIO_USE_SSL: "false"` (내부 통신은 평문)

## 업데이트

```bash
# 마이너 버전 업그레이드
sed -i 's/gitea:1.22/gitea:1.23/' /srv/lab-platform/gitea/docker-compose.yml

cd /srv/lab-platform/gitea
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d

# 자동 마이그레이션, 로그 확인
docker logs -f gitea
```

메이저 버전(예: 1.x → 2.x)은 release notes 필독.
