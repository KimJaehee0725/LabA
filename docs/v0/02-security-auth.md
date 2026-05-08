# 02. Security and Auth

## 보안 목표

서울대 서버라는 1차 보호를 신뢰하더라도, 플랫폼은 인터넷 노출 가능성을 전제로 설계한다.

v0 보안 목표:

- 외부 공개면 최소화
- 통합 인증과 MFA 기본화
- secret 유출 방지
- 서비스 간 권한 분리
- 백업과 복구 가능성 확보
- 업데이트 전후 검증 절차 고정

## 기본 보안 기준

1. 외부 공개 포트는 `80`, `443`, 필요 시 `2222`만 허용한다.
2. Postgres, Redis, MinIO API는 host에 bind하지 않는다.
3. 모든 브라우저 접근은 HTTPS만 허용한다.
4. 관리자 계정은 개인 계정과 service account를 분리한다.
5. Authentik MFA를 기본 인증 플로우에 포함한다.
6. 서비스별 DB user, bucket, secret을 분리한다.
7. Docker socket을 앱 컨테이너에 쉽게 넘기지 않는다.
8. split env 파일, 인증서 private key, backup archive는 파일 권한을 제한한다.
9. 로그에 secret이 찍히지 않도록 compose와 앱 설정을 점검한다.
10. 업데이트는 한 번에 전체가 아니라 서비스별로 진행한다.

## Authentik 그룹 모델

초기 그룹:

| 그룹 | 의미 | 기본 권한 |
|---|---|---|
| `lab-admin` | PI, 시스템 담당자 | 전체 관리자 |
| `lab-member` | 정규 연구실 멤버 | 일반 서비스 사용 |
| `lab-collab` | 외부 협업자 | 제한 접근 |
| `lab-guest` | 임시 게스트 | 최소 접근 |

권장 정책:

- `lab-admin`만 Authentik admin, MinIO admin, Gitea site admin 가능
- `lab-member`는 Plane/Gitea/Nextcloud/MLflow 기본 사용
- `lab-collab`은 프로젝트별 초대 기반
- `lab-guest`는 기본적으로 Plane/Nextcloud 일부 공유만 허용

## MFA

Authentik 기본 인증 플로우에 MFA validation stage를 추가한다.

권장:

- TOTP 허용
- WebAuthn 허용
- 신규 사용자는 첫 로그인 시 MFA 설정 강제
- `lab-admin`은 MFA 예외 금지

## 서비스별 인증 방식

| 서비스 | v0 인증 방식 | 메모 |
|---|---|---|
| Plane | OIDC | Provider/Application 생성 |
| Gitea | OIDC | auto registration은 허용하되 도메인/그룹 정책 필요 |
| Nextcloud | OIDC via `user_oidc` | `oidc_login`이 아니라 `user_oidc` 기준으로 통일 |
| MinIO Console | OIDC | policy claim 설계 필요 |
| MLflow | Authentik Forward Auth | 앱 자체 auth보다 proxy 보호 우선 |
| Overleaf CE | 수동 계정 | 공식 SSO 제약. LDAP outpost는 후속 검토 |
| Collabora | Nextcloud WOPI 연동 | 직접 사용자 로그인 없음 |

## OIDC 공통 원칙

공통 scope:

```text
openid email profile groups
```

공통 claims:

- `sub`
- `email`
- `name`
- `preferred_username`
- `groups`

주의:

- OIDC client secret은 Provider 생성 후 UI/API로 확인해서 해당 서비스 env 파일에 복사한다.
- callback/redirect URI는 실제 도메인 확정 후 한 번에 점검한다.
- group claim이 필요한 서비스는 Authentik property mapping에 `groups`를 포함한다.

## Forward Auth 원칙

MLflow처럼 자체 인증이 약하거나 계정 모델이 운영 목표와 맞지 않는 앱은 Authentik Forward Auth로 보호한다.

공식 Authentik 문서 기준으로 Forward Auth는 기존 reverse proxy가 실제 proxying을 담당하고, Authentik outpost가 인증/인가만 확인한다.

v0 원칙:

- MLflow는 single application forward auth로 시작한다.
- `/outpost.goauthentik.io` 경로만 outpost로 라우팅한다.
- 앱별 접근 정책을 유지하려면 domain-level보다 single application mode를 우선한다.
- outpost token은 해당 서비스 env 파일에 저장하고 파일 권한을 제한한다.
- outpost metrics port는 외부에 공개하지 않는다.

## Docker socket 주의

Authentik outpost는 Docker integration을 사용할 수 있지만, Docker socket은 강력한 권한이다.

v0 보안 기준:

- 가능하면 outpost 컨테이너를 수동 compose로 배포하고 token 기반으로 연결한다.
- Authentik core/worker에 Docker socket을 무조건 mount하지 않는다.
- Docker socket mount가 필요한 경우 별도 risk note와 운영자 승인 후 적용한다.

## Gitea 보안 기준

권장:

- 일반 registration 비활성화
- OIDC auto registration은 Authentik 정책과 함께 사용
- `ACCOUNT_LINKING=auto`는 편하지만, 동일 email 신뢰가 전제이므로 Authentik email verification 정책을 먼저 확인한다.
- private repository 기본
- LFS는 MinIO bucket으로 분리
- SSH 공개 시 `2222/tcp`만 허용

Gitea 문서상 OAuth2 auto registration, username source, account linking은 보안 영향이 있으므로 구현 단계에서 명시적으로 결정한다.

## Nextcloud 보안 기준

권장:

- `user_oidc`를 기준으로 Authentik 연동
- brute-force protection 유지
- app password는 WebDAV/학습 노드용으로만 사용
- 관리자 계정은 로컬 fallback으로 보존하되 MFA와 강한 비밀번호 사용
- public sharing은 기본 제한 후 필요 시 정책화

주의:

- Nextcloud primary storage를 MinIO로 바꾸는 결정은 나중에 되돌리기 어렵다.
- v0는 로컬 디스크 시작을 기본안으로 두고, 대용량 정책이 확정되면 재검토한다.

## MinIO 보안 기준

권장:

- root credential은 bootstrap 전용으로 관리한다.
- 서비스별 access key 또는 policy를 분리한다.
- Console은 OIDC로 보호하고 `lab-admin` 중심 정책을 둔다.
- API endpoint는 내부 `lab_data`에서만 접근한다.

MinIO OIDC에서는 discovery document URL, client ID/secret, claim name, role policy를 설정할 수 있다. policy claim 설계는 구현 전 별도 결정이 필요하다.

## Overleaf CE 보안 기준

Overleaf CE는 공식 SSO가 제한적이다.

v0 기본:

- 외부 공개는 Nginx TLS 뒤에서만
- 첫 admin 생성 후 registration URL은 즉시 폐기
- 사용자는 admin 초대 방식
- SMTP 설정 확인
- 필요 시 Authentik LDAP outpost 기반 인증을 후속 검토

## 운영 계정

계정 유형:

| 유형 | 예시 | 원칙 |
|---|---|---|
| 개인 관리자 | PI, 시스템 담당자 | MFA 필수, 공유 금지 |
| 서비스 계정 | backup, mlflow node | 최소 권한, 만료/회전 |
| 앱 bootstrap 계정 | initial admin | 초기 설정 후 비활성화 또는 강한 보호 |
| 학습 노드 토큰 | MLflow, MinIO, WebDAV | scope 제한, 주기적 회전 |

## 방화벽 초안

UFW 기준 예시:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
# 필요할 때만
ufw allow 2222/tcp
ufw enable
```

SSH 접근 포트와 학교 서버 정책은 실제 환경 확인 후 반영한다.
