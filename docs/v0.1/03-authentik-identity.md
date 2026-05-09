# 03. Authentik Identity Module

## 모듈 목표

Authentik은 모든 계정과 인증 정책의 기준이다.

포함:

- Authentik compose
- 그룹 blueprint
- MFA flow
- OIDC scope mapping
- 서비스별 Provider/Application skeleton
- MLflow Proxy Provider/Outpost 계획
- 사용자 lifecycle

## 공식 문서 반영사항

Authentik Docker Compose 공식 문서는 작은 production 설치에 Compose를 사용할 수 있다고 설명한다. 또한 기본 compose가 Docker socket을 worker에 mount해 outpost 관리를 자동화할 수 있지만, Docker socket mount는 보안 리스크가 있으므로 수동 outpost 배포 또는 socket proxy를 고려해야 한다.

v0.1 결정:

- Authentik은 Compose로 배포한다.
- Docker socket mount는 기본안에서 제외한다.
- MLflow outpost는 수동 compose 서비스로 관리한다.

## v0.2 산출물

```text
deploy/compose/authentik/docker-compose.yml
deploy/authentik/blueprints/10-groups.yaml
deploy/authentik/blueprints/20-oauth-scopes.yaml
deploy/authentik/blueprints/30-applications.yaml
deploy/authentik/blueprints/40-policies.yaml
deploy/scripts/20-check-authentik.sh
deploy/runbooks/authentik.md
```

## 의존성

- Postgres DB: `authentik`
- Redis DB: `0`
- Nginx route: `auth.lab.snu.ac.kr`
- SMTP: 권장

## 그룹 모델

| Group | 설명 | 기본 접근 |
|---|---|---|
| `lab-admin` | PI, 시스템 운영자 | 모든 서비스 admin 후보 |
| `lab-member` | 정규 연구실 멤버 | 기본 서비스 사용 |
| `lab-collab` | 외부 협업자 | 프로젝트별 제한 접근 |
| `lab-guest` | 임시 게스트 | 제한된 공유 접근 |

정책:

- `lab-admin`은 MFA 예외 불가.
- 외부 협업자는 만료일과 sponsor를 기록한다.
- guest는 기본적으로 앱 자동 가입 대상에서 제외한다.

## MFA 계획

기본:

- TOTP
- WebAuthn
- 신규 사용자 첫 로그인 시 설정 강제

v0.2 구현 방식:

- 우선 UI로 flow를 확인하고, blueprint 자동화는 보수적으로 적용한다.
- lockout 방지를 위해 bootstrap admin 계정과 recovery procedure를 문서화한다.

검증:

- 새 사용자 첫 로그인에서 MFA 설정 유도
- MFA 설정 후 Plane/Gitea/Nextcloud OIDC 로그인 가능
- admin 계정도 MFA 필수

## OIDC Scope Mapping

공통 scopes:

```text
openid email profile groups
```

`groups` custom mapping:

```python
return {
    "groups": [group.name for group in user.ak_groups.all()],
}
```

주의:

- 각 provider의 property mappings에 `groups`를 명시적으로 넣어야 한다.
- 서비스별로 group claim을 읽는 방식은 다를 수 있다.

## Applications and Providers

| Application | Provider type | Client ID | Redirect |
|---|---|---|---|
| Plane | OAuth2/OIDC | `plane` | `/auth/oidc/callback/` |
| Gitea | OAuth2/OIDC | `gitea` | `/user/oauth2/authentik/callback` |
| Nextcloud | OAuth2/OIDC | `nextcloud` | `/apps/user_oidc/code` |
| Grist | OAuth2/OIDC | `grist` | `/oauth2/callback` |
| MinIO Console | OAuth2/OIDC | `minio` | `/oauth_callback` |
| MLflow | Proxy Provider | none | Forward Auth outpost |

도메인 placeholder:

```text
https://lab.snu.ac.kr
https://hub.lab.snu.ac.kr
https://files.lab.snu.ac.kr
https://data.lab.snu.ac.kr
https://storage.lab.snu.ac.kr
https://mlflow.lab.snu.ac.kr
```

## Client secret 관리

Blueprint로 OAuth2 Provider를 만들면 secret이 자동 생성될 수 있다.

v0.2 절차:

1. Provider/Application 생성
2. UI 또는 API로 client secret 확인
3. 해당 서비스의 split env 파일에 기록
4. 앱 compose 재시작 또는 설정 반영
5. secret 값은 history나 git에 기록하지 않음

## MLflow Outpost

구성:

- Proxy Provider: `mlflow-proxy`
- Mode: Forward auth, single application
- External host: `https://mlflow.lab.snu.ac.kr`
- Internal host: `http://mlflow:5000`
- Outpost container: `authentik-outpost-mlflow`

네트워크:

- `lab_backend`

Secret:

- `AUTHENTIK_OUTPOST_MLFLOW_TOKEN`

주의:

- Docker socket을 Authentik worker에 주지 않고 outpost를 compose로 직접 띄운다.
- outpost token rotation 절차가 필요하다.

## 사용자 Lifecycle

### Onboarding

1. Authentik user 생성
2. email 확인
3. group 부여
4. 첫 로그인 시 MFA 등록
5. 필요한 앱에서 첫 OIDC 로그인
6. Gitea/Nextcloud 자동 프로비저닝 확인

### Offboarding

1. Authentik user disable
2. app password/token 폐기
3. Gitea SSH key/PAT 확인
4. Nextcloud share link 확인
5. MinIO access key가 개인에게 발급됐으면 폐기
6. Plane/Gitea/Nextcloud 소유 리소스 이관

## 검증 기준

Authentik 완료 조건:

- server/worker running
- admin login 가능
- group 4개 존재
- MFA flow 적용
- test user 로그인 가능
- OIDC discovery endpoint 접근 가능
- service provider secret 확인 가능
- MLflow outpost가 Authentik에서 connected

## v0.3 Smoke

- `lab-member` 사용자가 Gitea/Plane/Nextcloud에 OIDC로 로그인
- MFA 설정 없이 로그인하려는 신규 사용자가 MFA setup으로 이동
- MLflow 직접 접근 시 Authentik login으로 redirect
- disabled user가 모든 OIDC 서비스에서 차단됨

## 위험

| 위험 | 대응 |
|---|---|
| MFA flow 설정 오류로 admin lockout | bootstrap admin/recovery procedure 문서화 |
| client secret 유출 | split env 파일 권한, history 기록 금지 |
| Docker socket mount | 수동 outpost 배포 |
| group claim 누락 | OIDC token claim 확인 절차 추가 |
| 자동 가입 남용 | Authentik group policy와 app registration 제한 |
