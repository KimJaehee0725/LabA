# 05. Open Decisions

이 문서는 구현 전에 사용자가 결정하거나, 구현 단계에서 공식 문서로 재검증해야 할 항목이다.

## 반드시 결정할 항목

### 1. 실제 도메인

현재 `*.lab.snu.ac.kr`은 placeholder다.

결정 필요:

- root domain
- 서비스별 subdomain
- DNS 관리 주체
- 내부망 전용인지 외부 공개인지
- TLS 발급 방식

### 2. 배포 경로

v0 기본은 `/srv/lab-platform`이다.

결정 필요:

- 최종 운영 경로
- 데이터 볼륨을 같은 디스크에 둘지 별도 mount에 둘지
- 백업 archive를 같은 서버에 둘지 외부 스토리지에 둘지

### 3. Nextcloud storage

선택지:

| 방식 | 장점 | 단점 |
|---|---|---|
| 로컬 디스크 | 단순, 문제 해결 쉬움 | 용량 확장과 오프사이트 백업 고민 필요 |
| MinIO primary storage | object storage 일원화 | 초기 결정 후 변경이 매우 어려움 |

v0 기본안은 로컬 디스크 시작이다. 대용량 파일 요구가 명확하면 구현 전에 다시 결정한다.

### 4. Overleaf 인증

v0 기본안은 수동 사용자 초대다.

결정 필요:

- 수동 계정으로 시작해도 되는지
- Authentik LDAP outpost를 초기 범위에 포함할지
- Overleaf CE 대신 다른 LaTeX 협업 도구를 검토할지

### 5. MLflow 자동화 접근

브라우저 UI는 Forward Auth로 보호한다.

결정 필요:

- 학습 노드의 MLflow API 호출을 어떻게 인증할지
- 내부망 전용 API endpoint를 둘지
- Authentik token/header 기반 접근을 표준화할지
- 모델 artifact 업로드 credential 배포 방식을 어떻게 할지

### 6. Gitea 공개성

결정 필요:

- 모든 repo private 기본인지
- 로그인하지 않은 사용자의 read 접근을 허용할지
- 외부 협업자에게 어떤 organization 접근을 줄지
- SSH 포트 `2222`를 외부 공개할지

### 7. HWP viewer

`init_docs/06-nextcloud.md`에는 rhwp 기반 HWP/HWPX viewer 아이디어가 있다.

결정 필요:

- v0에 포함할지, Nextcloud 안정화 후 후속으로 둘지
- viewer 도메인을 둘지: `hwp.lab.snu.ac.kr`
- Nextcloud 파일 권한과 viewer fetch 권한을 어떻게 연결할지
- 외부 공유 링크에서도 동작하게 할지

v0 기본안은 후속 범위로 둔다.

### 8. SMTP

결정 필요:

- SMTP provider
- 발신 주소
- SPF/DKIM/DMARC
- Authentik invite/password reset
- Nextcloud/Overleaf/Gitea 알림 메일

### 9. 백업 보관 위치

결정 필요:

- 같은 서버 내 보관만 할지
- 다른 서버/NAS/object storage로 복제할지
- 백업 암호화 방식
- retention 기간
- restore drill 주기

## 현재 init_docs 불일치

### Nextcloud OIDC redirect URI

`init_docs/02-authentik.md`:

```text
https://files.lab.snu.ac.kr/apps/oidc_login/oidc
```

`init_docs/06-nextcloud.md`:

```text
https://files.lab.snu.ac.kr/apps/user_oidc/code
```

v0 결정:

- Nextcloud는 `user_oidc`를 권장 앱으로 둔다.
- 따라서 redirect URI는 `https://files.lab.snu.ac.kr/apps/user_oidc/code` 기준으로 통일한다.
- 구현 전 실제 설치한 `user_oidc` 버전의 문서로 재검증한다.

### Authentik blueprint와 client secret

문서에는 blueprint로 OAuth2 Provider를 생성하는 흐름이 있다. 단, client secret은 자동 생성되므로 `.env`에 바로 고정하기 어렵다.

v0 결정:

- 초기 구현에서는 Provider 생성 후 UI/API로 secret 확인
- 해당 서비스 env 파일에 수동 반영
- 나중에 bootstrap 자동화가 필요하면 Authentik API script를 별도 작성

### Plane compose 방식

Plane은 공식 install script가 안정적이라고 되어 있다. 그러나 공통 Postgres/Redis/MinIO를 쓰려면 공식 compose를 수정해야 한다.

v0 결정:

- 구현 단계에서 공식 compose를 받아온 뒤 변경점을 patch로 관리한다.
- Plane 버전 업데이트 시 compose diff를 필수 검토한다.

### MLflow Provider 방향

`init_docs/02-authentik.md`에는 MLflow OAuth2 Provider가 있고, `init_docs/03-mlflow.md`는 Authentik Forward Auth를 권장한다.

v0 결정:

- MLflow CE는 직접 OIDC 앱으로 취급하지 않는다.
- 외부 UI 접근은 Authentik Proxy Provider/Outpost 기반 Forward Auth로 보호한다.
- 학습 스크립트/API 접근 방식은 별도 결정 항목으로 남긴다.

### MinIO credential 사용

초기 문서 일부는 `MINIO_ROOT_USER/PASSWORD`를 앱 credential로 쓰는 예시가 있다.

v0 결정:

- 운영에서는 root credential을 앱에 공유하지 않는다.
- 서비스별 access key 또는 policy를 만든다.

### MinIO OIDC policy mapping

MinIO Console OIDC는 redirect URI만으로 끝나지 않는다. 로그인한 사용자가 실제로 어떤 bucket policy를 얻을지 결정해야 한다.

v0 결정:

- `lab-admin`은 admin console 접근 후보
- 서비스 간 S3 접근은 OIDC 사용자가 아니라 서비스별 access key/policy를 기본으로 둔다.
- OIDC claim 기반 policy mapping은 구현 전 MinIO 공식 문서로 재검증한다.

## 구현 단계에서 재검증할 공식 문서

- Plane self-hosted compose와 환경변수
- Authentik blueprint model schema
- Authentik Forward Auth nginx template
- Gitea OIDC/app.ini 설정
- MLflow auth/proxy 관련 변경 사항
- Nextcloud `user_oidc` callback URI와 occ 명령
- Collabora CODE domain/wopi 설정
- Overleaf CE toolkit 또는 image 구성
- MinIO OIDC와 policy claim 방식

## 나중에 넣을 수 있는 항목

v0 범위 밖:

- Prometheus/Grafana/Loki
- centralized audit log
- S3 lifecycle policy
- object lock 또는 immutable backup
- VPN 기반 관리자 접근
- CrowdSec/fail2ban
- Terraform/Ansible 자동화
- staging 서버
- HA Postgres/MinIO
- Kubernetes
