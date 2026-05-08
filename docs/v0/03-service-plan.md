# 03. Service Plan

## 서비스 매트릭스

| 서비스 | Placeholder URL | 인증 | 데이터 | v0 메모 |
|---|---|---|---|---|
| Authentik | `https://auth.lab.snu.ac.kr` | 자체 로그인 + MFA | Postgres, Redis, media volume | 모든 SSO의 기준 |
| Plane | `https://lab.snu.ac.kr` | OIDC | Postgres, Redis, MinIO | 메인 워크스페이스 |
| Gitea | `https://hub.lab.snu.ac.kr` | OIDC | Postgres, MinIO LFS, git volume | 코드/모델/데이터셋 |
| MLflow | `https://mlflow.lab.snu.ac.kr` | Forward Auth | Postgres, MinIO artifacts | 외부 접근은 Authentik 보호 |
| Nextcloud | `https://files.lab.snu.ac.kr` | OIDC via `user_oidc` | Postgres, data volume 또는 MinIO | 파일/캘린더/공동 문서 |
| Collabora | `https://office.lab.snu.ac.kr` | Nextcloud WOPI | runtime only | 직접 사용자 계정 없음 |
| Overleaf CE | `https://papers.lab.snu.ac.kr` | v0 수동 계정 | MongoDB, Redis, file volume | SSO는 후속 검토 |
| MinIO Console | `https://storage.lab.snu.ac.kr` | OIDC 후보 | MinIO data | admin 중심 접근 |
| HWP viewer | `https://hwp.lab.snu.ac.kr` | 결정 필요 | viewer runtime | Nextcloud rhwp 연동 시 후속 |

## Authentik

역할:

- 통합 로그인
- MFA
- 그룹/사용자 관리
- OIDC provider
- MLflow Forward Auth outpost
- 선택적으로 LDAP outpost

초기 산출물:

```text
/srv/lab-platform/authentik/blueprints/
├── 10-groups.yaml
├── 20-applications.yaml
└── 30-policies.yaml
```

주의:

- OAuth2 provider client secret은 blueprint 생성 후 자동 생성될 수 있다.
- 초기에는 UI에서 secret을 확인해 해당 서비스 env 파일에 복사하는 방식이 가장 명확하다.
- MFA flow 변경은 lockout 위험이 있으므로 로컬 admin fallback을 확인한 뒤 적용한다.

## Plane

역할:

- 프로젝트 관리
- 이슈/work item
- wiki/page
- 일정/협업 허브

의존성:

- Postgres DB: `plane`
- Redis DB: `2`
- MinIO bucket: `plane-uploads`

인증:

- Authentik OIDC

Redirect URI 후보:

```text
https://lab.snu.ac.kr/auth/oidc/callback/
https://lab.snu.ac.kr/api/auth/oidc/callback/
```

구현 메모:

- 공식 install script로 시작하되 내장 Postgres/Redis/MinIO는 제거하고 외부 core를 사용한다.
- 버전별 환경변수 차이가 있을 수 있으므로 구현 시 공식 compose와 diff를 확인한다.

## Gitea

역할:

- Git hosting
- Git LFS 기반 모델/데이터셋 저장
- 연구실 코드 및 논문 부속 저장소

의존성:

- Postgres DB: `gitea`
- Git volume: `/srv/lab-platform/data/gitea`
- MinIO bucket: `gitea-lfs`

인증:

- Authentik OIDC
- local admin fallback 유지

Redirect URI:

```text
https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback
```

초기 organization:

```text
lab-models
lab-datasets
lab-code
lab-papers
```

보안 메모:

- 일반 registration은 끈다.
- OAuth auto registration은 Authentik 그룹/메일 검증 정책이 준비된 뒤 켠다.
- `ACCOUNT_LINKING=auto`는 같은 email을 강하게 신뢰할 때만 사용한다.

## MLflow

역할:

- 실험 추적
- 모델 레지스트리
- artifact storage

의존성:

- Postgres DB: `mlflow`
- MinIO bucket: `mlflow-artifacts`

인증:

- v0 권장: Authentik Forward Auth
- 내부망 전용이라도 Nginx IP allowlist만으로 끝내지 않는다.

Forward Auth:

```text
external host: https://mlflow.lab.snu.ac.kr
internal host: http://mlflow:5000
```

학습 노드 접근:

- 브라우저 UI는 Authentik login
- 자동화/스크립트 접근은 별도 토큰 또는 내부망 전용 경로를 설계해야 한다.
- `MLFLOW_TRACKING_URI`와 MinIO credential 배포 방식은 별도 운영 문서 필요

## Nextcloud + Collabora

역할:

- 파일 저장
- 캘린더/연락처/태스크
- 공동 문서 편집
- 그룹 폴더

의존성:

- Postgres DB: `nextcloud`
- 파일 storage: v0 기본은 로컬 disk
- Collabora: 별도 컨테이너

인증:

- Authentik OIDC via `user_oidc`

Redirect URI 기준:

```text
https://files.lab.snu.ac.kr/apps/user_oidc/code
```

초기 필수 앱:

```text
richdocuments
user_oidc
calendar
contacts
notes
tasks
groupfolders
```

주의:

- `init_docs/02-authentik.md`에는 `oidc_login`용 redirect URI가 남아 있다.
- v0는 `user_oidc` 기준으로 통일한다.
- Nextcloud primary storage를 MinIO로 둘지는 구현 전 결정해야 한다.
- `rhwp` 기반 HWP/HWPX viewer는 v0 핵심 배포가 아니라 Nextcloud 안정화 이후 별도 앱/뷰어로 붙인다.

## Overleaf CE

역할:

- LaTeX 공동 편집
- 논문 프로젝트 관리

의존성:

- MongoDB
- Redis
- Overleaf file volume

인증:

- v0 기본: 수동 사용자 초대
- 후속 후보: Authentik LDAP outpost

운영 메모:

- CE는 Track Changes, real-time comments, rich project history가 제한된다.
- 최종 논문 산출물은 Gitea `lab-papers`로 push하는 규칙을 둔다.
- TeX Live 패키지는 커스텀 이미지로 고정하는 편이 재현성이 높다.

## MinIO

역할:

- Plane uploads
- Gitea LFS
- MLflow artifacts
- 선택적으로 Nextcloud primary storage
- 백업 staging 후보

인증:

- service access key 또는 policy 분리
- Console은 OIDC 검토

Bucket 후보:

```text
plane-uploads
gitea-lfs
mlflow-artifacts
nextcloud-primary   # 선택
backups             # 선택
```

주의:

- MinIO root user/password를 앱에서 공유하지 않는다.
- 각 앱에 전용 key/policy를 준다.

## 초기 구현 순서

1. Core network와 공통 인프라
2. Authentik
3. Gitea
4. Plane
5. MLflow
6. Nextcloud + Collabora
7. Overleaf CE

이 순서는 인증과 저장소를 먼저 안정화한 뒤, 더 복잡한 문서/실험 서비스를 붙이는 방식이다.
