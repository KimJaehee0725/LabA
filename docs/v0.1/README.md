# Lab Platform v0.1 Detailed Planning

작성일: 2026-05-08

v0.1의 목표는 v0 청사진을 실제 구현 직전 수준으로 세분화하는 것이다. v0.2에서는 이 문서들을 기준으로 각 모듈의 compose, nginx, bootstrap script, blueprint, 운영 스크립트를 만든다. v0.3에서는 전체 1차 작업물을 올리고 smoke test를 통과시키는 것을 목표로 한다.

## 버전 목표

| 버전 | 목표 | 산출물 |
|---|---|---|
| v0 | 전체 청사진 | 아키텍처, 보안 원칙, 서비스 목록, open decisions |
| v0.1 | 상세 기획 | 모듈별 구현 계획, 검증 기준, v0.2 backlog |
| v0.2 | 모듈별 구현 | compose, nginx, blueprints, scripts, env example |
| v0.3 | 1차 통합 검증 | 전 서비스 기동, 로그인/업로드/백업 smoke test |

## 문서 목록

| 문서 | 내용 |
|---|---|
| [00-v0.2-v0.3-roadmap.md](./00-v0.2-v0.3-roadmap.md) | v0.2 구현 순서와 v0.3 smoke target |
| [01-core-infrastructure.md](./01-core-infrastructure.md) | 디렉토리, 네트워크, Postgres, Redis, MinIO, env |
| [02-edge-nginx-tls.md](./02-edge-nginx-tls.md) | Nginx, TLS, 방화벽, proxy snippets |
| [03-authentik-identity.md](./03-authentik-identity.md) | Authentik, 그룹, MFA, OIDC, outpost |
| [04-gitea-module.md](./04-gitea-module.md) | Gitea, OIDC, LFS, organization, SSH |
| [05-plane-module.md](./05-plane-module.md) | Plane, 외부 DB/Redis/MinIO, OIDC |
| [06-mlflow-module.md](./06-mlflow-module.md) | MLflow, artifact store, Forward Auth |
| [07-nextcloud-collabora-module.md](./07-nextcloud-collabora-module.md) | Nextcloud, Collabora, OIDC, group folders |
| [08-overleaf-module.md](./08-overleaf-module.md) | Overleaf CE, Toolkit 판단, 계정, TeX Live |
| [09-backup-restore-observability.md](./09-backup-restore-observability.md) | 백업, 복구, 로그, 최소 모니터링 |
| [10-v0.2-implementation-backlog.md](./10-v0.2-implementation-backlog.md) | v0.2 작업 티켓 후보 |
| [11-v0.3-smoke-test-plan.md](./11-v0.3-smoke-test-plan.md) | 1차 통합 smoke test 체크리스트 |
| [12-env-and-git-operations.md](./12-env-and-git-operations.md) | env 분할과 git/branch/worktree 운영 원칙 |
| [13-data-model.md](./13-data-model.md) | v0.3 Lab domain data model과 demo seed catalog |

## v0.1 설계 원칙

1. 보안을 편의보다 우선한다.
2. 단일 대형 compose보다 모듈별 compose를 선호한다.
3. 공식 compose를 무시하고 재작성하지 않는다. 필요한 경우 override나 patch로 관리한다.
4. secret은 예시와 실제 파일을 분리한다.
5. 각 모듈은 독립 검증 기준을 가진다.
6. v0.3 smoke test가 가능한 최소 기능을 먼저 완성한다.
7. 후속 확장 기능은 v0.3 이후로 명확히 분리한다.

## 공식 참고 링크

- Plane self-hosting: https://developers.plane.so/self-hosting/overview
- Authentik Docker Compose: https://docs.goauthentik.io/install-config/install/docker-compose/
- Authentik Forward Auth: https://docs.goauthentik.io/add-secure-apps/providers/proxy/forward_auth
- Gitea config cheat sheet: https://docs.gitea.com/administration/config-cheat-sheet
- Gitea authentication: https://docs.gitea.com/usage/authentication
- MLflow artifact stores: https://mlflow.org/docs/latest/self-hosting/architecture/artifact-store/
- Nextcloud OIDC authentication: https://docs.nextcloud.com/server/latest/admin_manual/configuration_user/user_auth_oidc.html
- Overleaf Toolkit: https://docs.overleaf.com/on-premises/getting-started/what-is-the-overleaf-toolkit
- MinIO identity management: https://min.io/docs/minio/linux/administration/identity-access-management/minio-identity-management.html
