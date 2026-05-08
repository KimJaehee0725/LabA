# 03. MLflow

실험 추적 + 모델 레지스트리. W&B 대체.

## 공식 자료

- 문서: https://mlflow.org/docs/latest/index.html
- GitHub: https://github.com/mlflow/mlflow

## 인증 옵션

MLflow CE는 자체 인증이 약합니다. 세 가지 옵션:

### 옵션 A: 인증 없음 (내부망 한정)

학교/연구실 내부망에서만 접근 시 가장 간단. Nginx에서 IP 제한:

```nginx
# /srv/lab-platform/nginx/conf.d/30-mlflow.conf
location / {
    allow 192.168.0.0/16;
    allow 10.0.0.0/8;
    deny all;
    proxy_pass http://mlflow:5000;
}
```

### 옵션 B: MLflow basic-auth (자체 기능)

MLflow 2.5+에 내장된 BasicAuth.

```yaml
environment:
  MLFLOW_AUTH_CONFIG_PATH: /etc/mlflow/basic_auth.ini
```

```ini
# /srv/lab-platform/mlflow/basic_auth.ini
[mlflow]
default_permission = READ
database_uri = postgresql://...
admin_username = admin
admin_password = <generated>
```

명령어 실행:
```yaml
command: >
  mlflow server
  --app-name basic-auth
  ...
```

### 옵션 C: Authentik Forward Auth (권장)

Nginx auth_request로 Authentik 통한 SSO. **외부 접근 시 권장**.

#### 1. Authentik에서 Proxy Provider 생성

Provider:
- Type: **Proxy Provider**
- Name: `mlflow-proxy`
- Mode: `Forward auth (single application)`
- External host: `https://mlflow.lab.snu.ac.kr`
- Internal host: `http://mlflow:5000`

Application:
- Name: `MLflow`
- Slug: `mlflow`
- Provider: `mlflow-proxy`

#### 2. Outpost 생성

- Outposts > Create
- Name: `mlflow-outpost`
- Type: `Proxy`
- Applications: MLflow 선택
- Configuration:
  ```yaml
  authentik_host: https://auth.lab.snu.ac.kr
  authentik_host_insecure: false
  ```
- Outpost Token 자동 생성됨

#### 3. Outpost 컨테이너 추가

`/srv/lab-platform/authentik/docker-compose.yml`에 추가:

```yaml
  authentik-outpost-mlflow:
    image: ghcr.io/goauthentik/proxy:2024.10
    container_name: authentik-outpost-mlflow
    restart: unless-stopped
    networks:
      - lab_backend
    environment:
      AUTHENTIK_HOST: https://auth.lab.snu.ac.kr
      AUTHENTIK_INSECURE: "false"
      AUTHENTIK_TOKEN: ${AUTHENTIK_OUTPOST_MLFLOW_TOKEN}
```

`.env`에 토큰 추가:
```
AUTHENTIK_OUTPOST_MLFLOW_TOKEN=<outpost token>
```

#### 4. Nginx 라우팅 변경

```nginx
# /srv/lab-platform/nginx/conf.d/30-mlflow.conf
server {
    listen 443 ssl http2;
    server_name mlflow.lab.snu.ac.kr;

    ssl_certificate     /etc/nginx/ssl/origin.crt;
    ssl_certificate_key /etc/nginx/ssl/origin.key;
    include /etc/nginx/snippets/ssl-params.conf;
    include /etc/nginx/snippets/security-headers.conf;

    client_max_body_size 50G;
    proxy_request_buffering off;
    proxy_buffering off;

    # ===== Authentik Forward Auth =====
    location /outpost.goauthentik.io {
        proxy_pass http://authentik-outpost-mlflow:9000/outpost.goauthentik.io;
        include /etc/nginx/snippets/proxy-params.conf;
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    }

    location / {
        # 1) 인증 검증
        auth_request     /outpost.goauthentik.io/auth/nginx;
        error_page       401 = @goauthentik_proxy_signin;

        # 2) 사용자 정보를 헤더로 전달
        auth_request_set $authentik_username $upstream_http_x_authentik_username;
        auth_request_set $authentik_email    $upstream_http_x_authentik_email;
        proxy_set_header X-Forwarded-User    $authentik_username;
        proxy_set_header X-Forwarded-Email   $authentik_email;

        # 3) MLflow로 프록시
        proxy_pass http://mlflow:5000;
        include /etc/nginx/snippets/proxy-params.conf;
    }

    location @goauthentik_proxy_signin {
        internal;
        add_header Set-Cookie $auth_cookie;
        return 302 /outpost.goauthentik.io/start?rd=$request_uri;
    }
}
```

## 학습 노드에서 사용

### 환경변수

```bash
# ~/.bashrc 또는 별도 파일
export MLFLOW_TRACKING_URI="https://mlflow.lab.snu.ac.kr"

# Authentik Forward Auth 사용 시 — 학습 스크립트는 사용자 토큰을 헤더에 전달
export MLFLOW_TRACKING_TOKEN="<authentik_token>"

# MinIO 자격증명
export AWS_ACCESS_KEY_ID="<minio_user>"
export AWS_SECRET_ACCESS_KEY="<minio_password>"
export MLFLOW_S3_ENDPOINT_URL="http://minio.lab.local:9000"  # VPN 내부
```

### 학습 스크립트 예시

```python
import mlflow
import os

mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
mlflow.set_experiment("grpo-belief-shift-pilot")

with mlflow.start_run(run_name="qwen2.5-math-7b-bsr-coef-0.5") as run:
    # 하이퍼파라미터
    mlflow.log_params({
        "model": "Qwen2.5-Math-7B",
        "lr": 1e-6,
        "kl_coef": 0.04,
        "bsr_coef": 0.5,
        "rollout_n": 8,
    })

    # 학습 루프
    for step in range(1000):
        train_one_step()
        if step % 10 == 0:
            mlflow.log_metrics({
                "reward_mean": ...,
                "kl_div": ...,
                "policy_loss": ...,
            }, step=step)

    # 모델 저장
    mlflow.log_artifact("checkpoints/final/", artifact_path="model")
    mlflow.register_model(
        f"runs:/{run.info.run_id}/model",
        name="qwen2.5-math-bsr",
    )
```

### GRPO TRL 통합

HuggingFace TRL과 MLflow:

```python
from trl import GRPOConfig, GRPOTrainer

config = GRPOConfig(
    output_dir="./output",
    num_train_epochs=1,
    learning_rate=1e-6,
    report_to="mlflow",  # ← 이게 핵심
    run_name="grpo-bsr-exp1",
)
```

`MLFLOW_TRACKING_URI` 환경변수가 설정되어 있으면 자동 연동.

## 백업 항목

| 데이터 | 위치 |
|---|---|
| 메타데이터 | postgres `mlflow` DB |
| 아티팩트 (모델, 메트릭 등) | MinIO `mlflow-artifacts` 버킷 |
| 설정 | `.env`, `docker-compose.yml`, `Dockerfile` |

대용량 모델은 MinIO에 쌓이므로 주기적 정리 필요. 오래된 실험은 archive로 이동:
```bash
docker exec minio mc mv local/mlflow-artifacts/old-experiment local/backups/
```

## 모델 레지스트리 활용

MLflow의 Model Registry로 모델 버전 관리:

```python
# 학습 후 등록
result = mlflow.register_model(
    f"runs:/{run_id}/model",
    name="qwen2.5-math-bsr",
)

# Production 단계 변경
client = mlflow.MlflowClient()
client.transition_model_version_stage(
    name="qwen2.5-math-bsr",
    version=result.version,
    stage="Staging",  # None / Staging / Production / Archived
)
```

추론 노드에서:
```python
model_uri = "models:/qwen2.5-math-bsr/Production"
model = mlflow.transformers.load_model(model_uri)
```

## 트러블슈팅

**아티팩트 업로드 실패**:
- MinIO `mlflow-artifacts` 버킷 존재 확인
- `MLFLOW_S3_ENDPOINT_URL` 학습 노드 → 서버 통신 확인
- AWS 자격증명 (MinIO 사용자) 확인

**UI 느림**:
- Postgres 인덱스 확인: `EXPLAIN ANALYZE SELECT ...`
- 오래된 deleted runs 영구 삭제: `mlflow gc --backend-store-uri ...`

**Authentik forward auth 후 401 반복**:
- Outpost 컨테이너 로그 확인
- `auth_request` 응답 헤더 확인
- 쿠키 도메인 확인 (`mlflow.lab.snu.ac.kr` vs `lab.snu.ac.kr`)

## 업데이트

```bash
# Dockerfile의 베이스 이미지 태그 변경
sed -i 's/mlflow:v2.18.0/mlflow:v2.19.0/' /srv/lab-platform/mlflow/Dockerfile

cd /srv/lab-platform/mlflow
docker compose --env-file ../.env build
docker compose --env-file ../.env up -d
```
