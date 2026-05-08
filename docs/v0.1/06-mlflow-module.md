# 06. MLflow Module

## 모듈 목표

MLflow는 실험 추적, artifact storage, 모델 레지스트리 역할을 한다.

포함:

- MLflow compose 또는 Dockerfile
- Postgres backend store
- MinIO artifact store
- Authentik Forward Auth
- 학습 노드 접근 원칙
- smoke experiment

## 공식 문서 반영사항

MLflow 공식 문서는 run metadata를 backend store에 저장하고, artifact는 별도 artifact store에 저장한다고 설명한다. S3-compatible storage는 `s3://bucket/path` URI와 AWS credential 환경변수로 설정한다. artifact root를 명시하지 않으면 local file store에 저장될 수 있으므로 v0.2에서 반드시 `--default-artifact-root`를 고정해야 한다.

v0.1 결정:

- Backend store: Postgres
- Artifact store: MinIO S3-compatible bucket
- UI external access: Authentik Forward Auth
- v0.3 smoke는 browser UI와 artifact upload 중심

## v0.2 산출물

```text
deploy/compose/mlflow/docker-compose.yml
deploy/compose/mlflow/Dockerfile
deploy/nginx/conf.d/40-mlflow.conf
deploy/scripts/60-check-mlflow.sh
deploy/runbooks/mlflow.md
```

## 의존성

- Postgres DB: `mlflow`
- MinIO bucket: `mlflow-artifacts`
- Authentik Proxy Provider/Outpost
- Nginx: `mlflow.lab.snu.ac.kr`

## Server command 계획

후보:

```bash
mlflow server \
  --host 0.0.0.0 \
  --port 5000 \
  --backend-store-uri postgresql://mlflow_user:${MLFLOW_DB_PASSWORD}@postgres:5432/mlflow \
  --default-artifact-root s3://mlflow-artifacts \
  --serve-artifacts
```

환경:

```dotenv
AWS_ACCESS_KEY_ID=${MLFLOW_S3_ACCESS_KEY}
AWS_SECRET_ACCESS_KEY=${MLFLOW_S3_SECRET_KEY}
MLFLOW_S3_ENDPOINT_URL=http://minio:9000
```

주의:

- `--default-artifact-root`를 `http://minio:9000` 같은 endpoint로 지정하지 않는다.
- artifact URI는 `s3://mlflow-artifacts` 계열로 둔다.
- endpoint URL은 S3 client 환경변수로 둔다.

## Authentik Forward Auth

구성:

- Authentik Proxy Provider: `mlflow-proxy`
- Outpost: `authentik-outpost-mlflow`
- Nginx `auth_request`

접근:

- browser access는 Authentik login required
- unauthenticated access는 302 또는 401

주의:

- MLflow API client가 browser cookie를 쓰기 어렵다.
- v0.2에서는 학습 노드용 API 인증 방식을 별도 open decision으로 유지한다.
- 내부망/VPN 전용 API endpoint가 필요한지 검토한다.

## 학습 노드 접근 초안

v0.3 smoke 후보:

1. 서버 내부 또는 VPN 내부에서 test script 실행
2. `MLFLOW_TRACKING_URI=https://mlflow.lab.snu.ac.kr`
3. 인증은 임시로 browser/session 또는 내부 bypass 없이 수동 검증
4. artifact upload가 MinIO bucket에 남는지만 확인

v0.4 이후 결정:

- Basic auth
- service token
- internal-only API host
- Authentik token forwarding

## Smoke script 계획

```python
import mlflow

mlflow.set_tracking_uri("https://mlflow.lab.snu.ac.kr")
mlflow.set_experiment("smoke")

with mlflow.start_run(run_name="v0.3-smoke"):
    mlflow.log_param("platform_version", "v0.3")
    mlflow.log_metric("ok", 1)
    with open("/tmp/mlflow-smoke.txt", "w") as f:
        f.write("ok")
    mlflow.log_artifact("/tmp/mlflow-smoke.txt")
```

인증 방식이 미정이면 내부 컨테이너에서 direct `http://mlflow:5000`로 artifact path만 먼저 검증하고, 외부 UI 인증은 별도 검증한다.

## 백업

대상:

- Postgres `mlflow`
- MinIO `mlflow-artifacts`
- MLflow compose/env

주의:

- run 삭제는 artifact를 자동 삭제하지 않을 수 있다.
- 오래된 run/artifact 정리 정책은 운영 후 별도 수립한다.

## 검증 기준

MLflow 완료 조건:

- MLflow server running
- backend store가 Postgres
- artifact root가 MinIO bucket
- 인증 전 UI 접근 차단
- 인증 후 UI 접근 가능
- experiment/run 생성
- artifact upload 후 MinIO object 확인

## 위험

| 위험 | 대응 |
|---|---|
| artifact가 local volume에 저장됨 | default artifact root와 bucket object 확인 |
| Forward Auth가 API client를 막음 | v0.3 범위와 v0.4 자동화 인증을 분리 |
| 대용량 artifact timeout | Nginx buffering/upload 설정 |
| MinIO endpoint/path 오류 | S3 URI와 endpoint env를 분리 |

