# Lab Platform v0 Blueprint

작성일: 2026-05-08

이 디렉토리는 연구실 self-hosted 플랫폼의 v0 청사진입니다. 목표는 바로 운영 파일을 만들기 전에, 배포 구조와 보안 원칙, 서비스별 의존성, 구축 순서, 아직 결정해야 할 항목을 구체적으로 고정하는 것입니다.

현재 전제:

- 서버: Ubuntu
- 런타임: Docker, Docker Compose 사용 가능
- 권한: root 또는 sudo 가능
- 임시 배포 경로: `/srv/lab-platform`
- 도메인: 아직 없음. 문서의 `*.lab.snu.ac.kr` 계열은 placeholder
- 인증 방향: Authentik 중심 통합 계정 관리
- 우선순위: 안정성, 보안, 백업 가능성, 단계적 구축

## 문서 목록

| 문서 | 내용 |
|---|---|
| [00-system-blueprint.md](./00-system-blueprint.md) | 전체 목표, 아키텍처, 핵심 결정 |
| [01-infrastructure.md](./01-infrastructure.md) | 디렉토리, Docker network, 공통 인프라, 포트 정책 |
| [02-security-auth.md](./02-security-auth.md) | 보안 기준, Authentik, MFA, 서비스별 인증 원칙 |
| [03-service-plan.md](./03-service-plan.md) | 서비스별 URL, 데이터 의존성, 인증 방식, 구현 메모 |
| [04-rollout-ops.md](./04-rollout-ops.md) | 단계별 구축 순서, 검증, 백업, 업데이트 운영 |
| [05-open-decisions.md](./05-open-decisions.md) | 구현 전 결정할 사항과 현재 문서 불일치 |

다음 단계의 상세 계획은 [../v0.1/](../v0.1/)에 있다.

## v0 결정 요약

1. 공통 인프라 스택을 먼저 만든다.
   - Postgres, Redis, MinIO, Nginx, 백업 스켈레톤을 core로 둔다.
   - 각 애플리케이션은 별도 Compose 프로젝트로 붙인다.

2. 외부 공개 진입점은 Nginx로 제한한다.
   - 기본 공개 포트는 `80/tcp`, `443/tcp`.
   - Gitea SSH가 필요하면 `2222/tcp`만 추가 공개한다.
   - Postgres, Redis, MinIO API, 내부 앱 포트는 외부 bind 금지.

3. 계정 관리는 Authentik을 중심으로 한다.
   - Plane, Gitea, Nextcloud, MinIO Console은 OIDC 우선.
   - MLflow는 앱 자체 인증보다 Authentik Forward Auth 우선.
   - Overleaf CE는 공식 SSO 제약 때문에 v0에서는 수동 계정으로 시작하고, 필요하면 Authentik LDAP outpost를 후속 검토한다.

4. 구현은 한 번에 전체를 올리지 않는다.
   - core -> authentik -> gitea -> plane -> mlflow -> nextcloud/collabora -> overleaf 순서로 진행한다.

5. secret은 git에 들어가지 않는다.
   - v0.1부터 실제 값은 `/srv/lab-platform/env/*.env`로 분할 관리한다.
   - repo에는 `*.env.example`만 둔다.

## 참고한 초기 문서

- `init_docs/01-plane.md`
- `init_docs/02-authentik.md`
- `init_docs/03-mlflow.md`
- `init_docs/04-gitea.md`
- `init_docs/05-overleaf.md`
- `init_docs/06-nextcloud.md`

## 공식 참고 링크

- Authentik Forward Auth: https://docs.goauthentik.io/add-secure-apps/providers/proxy/forward_auth
- Authentik Outposts: https://docs.goauthentik.io/add-secure-apps/outposts
- Nextcloud OIDC user authentication: https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_oidc.html
- Gitea configuration cheat sheet: https://docs.gitea.com/administration/config-cheat-sheet
- MinIO OpenID settings: https://min.io/docs/minio/linux/reference/minio-server/settings/iam/openid.html
