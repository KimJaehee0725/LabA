# 00. System Blueprint

## 목표

연구실 내부 운영을 위한 통합 플랫폼을 self-hosted로 구축한다.

핵심 목적:

- 프로젝트, 이슈, 위키, 일정: Plane
- 통합 인증, MFA, 그룹 관리: Authentik
- 실험 추적, 모델 레지스트리: MLflow
- 코드, 모델, 데이터셋 Git/LFS 저장소: Gitea
- 논문 LaTeX 공동 편집: Overleaf CE
- 파일 보관, 캘린더, 공동 문서 편집: Nextcloud + Collabora
- 공통 데이터 계층: Postgres, Redis, MinIO
- 외부 진입점과 TLS 종료: Nginx

## 비목표

v0 청사진 단계에서는 다음을 하지 않는다.

- 실제 secret 생성
- 실제 도메인 확정
- 운영 서버에 컨테이너 기동
- 서비스별 최신 compose 확정
- HA 구성
- Kubernetes 전환

## 전체 구조

```text
Internet / SNU network
        |
        v
  [Nginx reverse proxy]
        |
        +--------------------+
        | lab_backend         |
        |                     |
        |  Plane web/api      |
        |  Authentik server   |
        |  Gitea              |
        |  MLflow             |
        |  Nextcloud          |
        |  Collabora          |
        |  Overleaf           |
        +--------------------+
                  |
                  v
        +--------------------+
        | lab_data            |
        |                     |
        |  Postgres           |
        |  Redis              |
        |  MinIO              |
        +--------------------+
```

Nginx만 외부와 직접 연결된다. 각 앱은 필요한 내부 네트워크에만 붙인다.

## 핵심 결정

### 공통 인프라 우선

서비스별 DB/Redis/MinIO를 각각 띄우지 않고, 공통 core 스택을 둔다.

| 선택지 | 장점 | 단점 | v0 판단 |
|---|---|---|---|
| 서비스별 DB/Redis 포함 | 공식 compose를 거의 그대로 사용 가능 | 백업, 업데이트, 보안, 리소스 관리가 분산됨 | 장기 운영에는 부적합 |
| 공통 DB/Redis/MinIO | 백업과 보안 정책 일원화, 리소스 효율, 장애 추적 용이 | 초기 계정/DB/bucket 설계 필요 | v0 기본안 |

### Authentik 중심 계정 관리

가능한 모든 서비스는 Authentik을 통해 로그인한다. 단, 앱 자체의 지원 상태에 따라 방식은 다르게 둔다.

- OIDC 지원 앱: OIDC provider/application 사용
- 자체 인증이 약한 앱: Authentik Forward Auth 사용
- SSO가 공식적으로 약한 앱: 수동 계정으로 시작 후 LDAP outpost 검토

### 도메인은 변수화

초기 문서의 도메인은 placeholder다. 구현 시 아래처럼 변수화한다.

```text
ROOT_DOMAIN=lab.snu.ac.kr
AUTH_DOMAIN=auth.lab.snu.ac.kr
PLANE_DOMAIN=lab.snu.ac.kr
GITEA_DOMAIN=hub.lab.snu.ac.kr
MLFLOW_DOMAIN=mlflow.lab.snu.ac.kr
NEXTCLOUD_DOMAIN=files.lab.snu.ac.kr
COLLABORA_DOMAIN=office.lab.snu.ac.kr
OVERLEAF_DOMAIN=papers.lab.snu.ac.kr
MINIO_CONSOLE_DOMAIN=storage.lab.snu.ac.kr
```

실제 도메인이 확정되기 전에는 compose와 nginx 템플릿이 이 변수들을 참조하도록 설계한다.

## 데이터 소유권

각 서비스는 자기 DB와 자기 object bucket을 가진다.

| 서비스 | DB | Object storage | Redis |
|---|---|---|---|
| Authentik | `authentik` | media/certs는 파일 볼륨 | 사용 |
| Plane | `plane` | `plane-uploads` | 사용 |
| MLflow | `mlflow` | `mlflow-artifacts` | 선택 |
| Gitea | `gitea` | `gitea-lfs` | 선택 |
| Nextcloud | `nextcloud` | v0는 로컬 디스크 우선, MinIO는 결정 필요 | 내부 cache/lock용 사용 가능 |
| Overleaf | MongoDB | 파일 볼륨 | 자체 Redis |

Overleaf는 Postgres가 아니라 MongoDB/Redis 의존성이 있으므로 core Postgres와 별도로 취급한다.

## 안정성 원칙

1. 작은 단위로 구축한다.
2. 각 단계마다 로그인, 업로드, 백업, restore 가능성을 확인한다.
3. `latest` 태그를 운영 기준으로 쓰지 않는다. 버전은 명시한다.
4. secret은 파일 권한과 gitignore로 보호한다.
5. 외부 공개 포트는 최소화한다.
6. 서비스별 로그와 백업 위치를 고정한다.
7. 업데이트 전에 DB dump와 volume snapshot을 남긴다.

## 구현 산출물 목표

v0 청사진 이후 실제 구현 단계에서 만들 파일:

```text
/srv/lab-platform/
├── .env
├── .env.example
├── compose/
│   ├── core/docker-compose.yml
│   ├── authentik/docker-compose.yml
│   ├── plane/docker-compose.yml
│   ├── gitea/docker-compose.yml
│   ├── mlflow/docker-compose.yml
│   ├── nextcloud/docker-compose.yml
│   └── overleaf/docker-compose.yml
├── nginx/
│   ├── conf.d/
│   └── snippets/
├── authentik/
│   └── blueprints/
├── backups/
│   ├── scripts/
│   └── archive/
└── docs/
```
