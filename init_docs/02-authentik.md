# 02. Authentik

SSO + MFA. 모든 서비스의 인증 허브.

## 공식 자료

- 문서: https://goauthentik.io/docs
- Blueprints: https://goauthentik.io/docs/customize/blueprints
- Discord 커뮤니티: https://goauthentik.io/discord

## 핵심 개념

| 개념 | 설명 |
|---|---|
| Provider | 인증 메커니즘 (OAuth2/OIDC, SAML, LDAP, Proxy) |
| Application | 사용자에게 보이는 서비스. Provider와 1:1 매핑 |
| Flow | 인증 단계 시퀀스 (identification → password → MFA → login) |
| Stage | Flow의 각 단계 |
| Group | 사용자 그룹. RBAC 기반 |
| Outpost | Proxy/LDAP 등을 위한 별도 컨테이너 |
| Property Mapping | 사용자 속성 → 서비스 클레임 변환 |

## 그룹 설계

### 4개 기본 그룹

```yaml
# /srv/lab-platform/authentik/blueprints/10-groups.yaml
version: 1
metadata:
  name: lab-groups
entries:
  - model: authentik_core.group
    identifiers:
      name: lab-admin
    attrs:
      is_superuser: true
      attributes:
        description: "전체 시스템 관리자 (PI + 시스템 담당자)"

  - model: authentik_core.group
    identifiers:
      name: lab-member
    attrs:
      attributes:
        description: "정규 연구실 멤버"

  - model: authentik_core.group
    identifiers:
      name: lab-collab
    attrs:
      attributes:
        description: "외부 협업자 (제한된 접근)"

  - model: authentik_core.group
    identifiers:
      name: lab-guest
    attrs:
      attributes:
        description: "발표 참관 등 임시 게스트"
```

적용:
```bash
# blueprints 디렉토리에 yaml 파일을 두면 Authentik이 자동으로 로드
ls /srv/lab-platform/authentik/blueprints/

# 강제 재로드
docker exec authentik-worker ak apply_blueprints
```

## MFA 강제

기본 인증 플로우(`default-authentication-flow`)를 복제·수정해서 MFA 단계 추가.

### 방법 1: UI로 설정

1. Flows & Stages > Stages > Create
   - Type: `Authenticator Validation Stage`
   - Name: `lab-mfa-validate`
   - Device classes: TOTP, WebAuthn
   - Configuration stage: `default-authenticator-totp-setup`
   - Not Configured Action: **Configure**
2. Flows & Stages > Flows > `default-authentication-flow` > Stage Bindings
   - Add Stage Binding: `lab-mfa-validate`, Order: 30 (password 다음)

### 방법 2: Blueprint

```yaml
# /srv/lab-platform/authentik/blueprints/00-flows.yaml
version: 1
metadata:
  name: lab-flows
entries:
  - model: authentik_stages_authenticator_validate.authenticatorvalidatestage
    identifiers:
      name: lab-mfa-validate
    attrs:
      device_classes:
        - totp
        - webauthn
      not_configured_action: configure
      configuration_stages:
        - !Find [authentik_stages_authenticator_totp.authenticatortotpstage, [name, default-authenticator-totp-setup]]

  - model: authentik_flows.flowstagebinding
    identifiers:
      target: !Find [authentik_flows.flow, [slug, default-authentication-flow]]
      stage: !Find [authentik_stages_authenticator_validate.authenticatorvalidatestage, [name, lab-mfa-validate]]
    attrs:
      order: 30
```

## 서비스별 OIDC Application

각 서비스마다 Application + Provider 한 쌍 생성.

```yaml
# /srv/lab-platform/authentik/blueprints/20-applications.yaml
version: 1
metadata:
  name: lab-applications
entries:
  # ===== Plane =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: plane-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: plane
      redirect_uris: |-
        https://lab.snu.ac.kr/auth/oidc/callback/
        https://lab.snu.ac.kr/api/auth/oidc/callback/
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
        - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]

  - model: authentik_core.application
    identifiers:
      slug: plane
    attrs:
      name: Plane
      provider: !KeyOf plane-provider
      meta_launch_url: https://lab.snu.ac.kr
      meta_icon: /media/plane-logo.png

  # ===== MLflow =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: mlflow-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: mlflow
      redirect_uris: https://mlflow.lab.snu.ac.kr/oauth/callback/

  - model: authentik_core.application
    identifiers:
      slug: mlflow
    attrs:
      name: MLflow
      provider: !KeyOf mlflow-provider
      meta_launch_url: https://mlflow.lab.snu.ac.kr

  # ===== Gitea =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: gitea-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: gitea
      redirect_uris: https://hub.lab.snu.ac.kr/user/oauth2/authentik/callback

  - model: authentik_core.application
    identifiers:
      slug: gitea
    attrs:
      name: Gitea
      provider: !KeyOf gitea-provider
      meta_launch_url: https://hub.lab.snu.ac.kr

  # ===== Overleaf =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: overleaf-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: overleaf
      redirect_uris: https://papers.lab.snu.ac.kr/oauth/callback

  - model: authentik_core.application
    identifiers:
      slug: overleaf
    attrs:
      name: Overleaf
      provider: !KeyOf overleaf-provider
      meta_launch_url: https://papers.lab.snu.ac.kr

  # ===== Nextcloud =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: nextcloud-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: nextcloud
      redirect_uris: https://files.lab.snu.ac.kr/apps/oidc_login/oidc

  - model: authentik_core.application
    identifiers:
      slug: nextcloud
    attrs:
      name: Nextcloud
      provider: !KeyOf nextcloud-provider
      meta_launch_url: https://files.lab.snu.ac.kr

  # ===== MinIO =====
  - model: authentik_providers_oauth2.oauth2provider
    identifiers:
      name: minio-provider
    attrs:
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      client_type: confidential
      client_id: minio
      redirect_uris: https://storage.lab.snu.ac.kr/oauth_callback

  - model: authentik_core.application
    identifiers:
      slug: minio
    attrs:
      name: MinIO Console
      provider: !KeyOf minio-provider
      meta_launch_url: https://storage.lab.snu.ac.kr
```

**중요**: Blueprint로 생성된 OAuth2 Provider의 client_secret은 자동 생성되며, UI에서 확인하거나 API로 조회해야 합니다. 처음에는 UI에서 Provider 열어서 확인 후 `.env`에 복사가 가장 확실.

## 그룹 매핑 정책 (Custom Scope)

Plane 등이 사용자의 그룹 정보를 받으려면 `groups` 클레임 필요.

```yaml
# /srv/lab-platform/authentik/blueprints/30-policies.yaml
version: 1
metadata:
  name: lab-policies
entries:
  - model: authentik_providers_oauth2.scopemapping
    identifiers:
      managed: lab-groups-mapping
    attrs:
      name: "OAuth2 - Lab Groups"
      scope_name: groups
      description: "User's lab group membership"
      expression: |
        return {
            "groups": [group.name for group in user.ak_groups.all()],
        }
```

생성 후 각 Provider의 `property_mappings`에 추가:
```yaml
property_mappings:
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, openid]]
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, email]]
  - !Find [authentik_providers_oauth2.scopemapping, [scope_name, profile]]
  - !Find [authentik_providers_oauth2.scopemapping, [managed, lab-groups-mapping]]
```

## 사용자 추가 절차

### Admin이 수동 추가

Authentik UI에서:
1. Directory > Users > Create
2. Username, Name, Email 입력
3. **Path**: `/lab/`
4. 그룹에 추가: `lab-member`
5. "Set initial password" 또는 "Send invite link"

### 자가 가입 (선택)

`default-source-enrollment-flow`를 활성화하면 사용자가 직접 가입 가능. 단, 자동으로 그룹 부여하려면 Policy 추가 필요.

## API 토큰 (학습 노드용)

학습 노드에서 MLflow 등에 접근할 때 사용:

1. Authentik UI > Directory > Tokens > Create
2. User: `<service-account>` 또는 멤버 본인
3. Intent: `app_password` 또는 `api`
4. Expires: 6개월 권장
5. 토큰 복사 → 학습 노드 환경변수

```bash
# 학습 노드 ~/.lab-credentials
export AUTHENTIK_TOKEN="lab_pat_xxxxxxxxxxxxxxxxxxxxxxx"
export MLFLOW_TRACKING_URI="https://mlflow.lab.snu.ac.kr"
```

## 백업 항목

| 데이터 | 위치 |
|---|---|
| DB | postgres `authentik` DB |
| Blueprints | `/srv/lab-platform/authentik/blueprints/` |
| Media (로고 등) | `/srv/lab-platform/authentik/media/` |
| Certs | `/srv/lab-platform/authentik/certs/` |

DB 백업이 가장 중요. Blueprints는 Git으로도 관리 권장.

## 트러블슈팅

**OIDC 로그인 후 그룹 정보 안 옴**:
- Provider의 Property Mappings에 `lab-groups-mapping` 포함 확인
- 클라이언트 측 OIDC scope에 `groups` 포함 확인

**Blueprint가 적용 안 됨**:
```bash
docker exec authentik-worker ak apply_blueprints --force
docker logs authentik-worker | grep blueprint
```

**사용자가 MFA 없이 로그인됨**:
- Flow Stage Binding에 MFA stage가 포함됐는지
- `not_configured_action: configure`로 신규 사용자 강제

**Forgot password 작동 안 함**:
- SMTP 환경변수 확인
- `docker exec authentik-worker ak send_email_test admin@snu.ac.kr`

## 업데이트

Authentik은 자주 업데이트됨. 메이저 버전(예: 2024.10 → 2025.x)은 반드시 release notes 확인.

```bash
# .env에서 이미지 태그 변경 후
cd /srv/lab-platform/authentik
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d

# 마이그레이션은 자동 실행
docker logs -f authentik-server
```
