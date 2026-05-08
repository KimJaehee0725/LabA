# 01. Plane

메인 워크스페이스. 위키 + 프로젝트 + 이슈 + 일정 통합.

## 공식 자료

- 문서: https://docs.plane.so
- GitHub: https://github.com/makeplane/plane
- self-hosted 가이드: https://developers.plane.so/self-hosting

## 디렉토리

```
/srv/lab-platform/plane/
├── docker-compose.yml
├── .env                  # 전역 .env에서 변수 가져옴
└── data/
    ├── uploads/          # 첨부 파일 (외부 MinIO 사용 권장)
    └── logs/
```

## 설치 절차

### 옵션 A: 공식 install script (가장 안정적)

```bash
cd /srv/lab-platform/plane
curl -fsSL https://prime.plane.so/install/setup.sh | bash
```

스크립트가 만든 `docker-compose.yml`을 열어 다음 항목 수정:

1. `services:` 안의 `plane-db` (Postgres) 블록 삭제 → 외부 `postgres` 사용
2. `services:` 안의 `plane-redis` 블록 삭제 → 외부 `redis` 사용
3. `services:` 안의 `plane-minio` 블록 삭제 → 외부 `minio` 사용
4. `networks:` 블록을 외부 네트워크 참조로 변경:

```yaml
networks:
  lab_backend:
    external: true
  lab_data:
    external: true
```

5. 각 서비스의 `networks:` 항목을 다음으로 변경:
```yaml
    networks:
      - lab_backend  # web, space, admin
      - lab_data     # api, worker, beat
```

6. 환경변수에서 DB/Redis/MinIO 연결 주소를 외부 인스턴스로:
```
DATABASE_URL=postgresql://${PLANE_DB_USER}:${PLANE_DB_PASSWORD}@postgres/${PLANE_DB_NAME}
REDIS_URL=redis://default:${REDIS_PASSWORD}@redis:6379/2
AWS_S3_ENDPOINT_URL=http://minio:9000
AWS_S3_BUCKET_NAME=plane-uploads
```

### 옵션 B: 직접 작성

`Day 2` 문서의 골격을 사용하되, Plane GitHub의 `deploy/selfhost/docker-compose.yml`을 참조해 환경변수 누락 없이 채워넣어야 합니다. 메이저 버전이 올라가면 환경변수가 추가/제거되므로 항상 최신 공식 파일과 diff 확인을 권장합니다.

## Authentik OIDC 연동

### 1단계: Authentik에서 Provider/Application 생성

Authentik 관리자 UI에서:

**Provider 생성**:
- Type: OAuth2/OpenID Provider
- Name: `plane-provider`
- Authorization flow: `default-provider-authorization-implicit-consent`
- Client type: Confidential
- Client ID: `plane`
- Redirect URIs:
  ```
  https://lab.snu.ac.kr/auth/oidc/callback/
  https://lab.snu.ac.kr/api/auth/oidc/callback/
  ```
- Signing Key: `authentik Self-signed Certificate`
- Scopes: `openid`, `email`, `profile`

생성 후 표시되는 **Client Secret 복사**.

**Application 생성**:
- Name: `Plane`
- Slug: `plane`
- Provider: 위에서 만든 `plane-provider`
- Launch URL: `https://lab.snu.ac.kr`

**그룹 매핑** (Property Mappings):
사용자의 Authentik 그룹을 Plane에 전달하려면 Custom Scope Mapping 필요:

```python
# Authentik > Customization > Property Mappings > Create Scope Mapping
# Name: groups
# Scope name: groups
# Expression:
return {
    "groups": [group.name for group in user.ak_groups.all()]
}
```

### 2단계: `.env` 갱신

```bash
# /srv/lab-platform/.env
PLANE_OIDC_CLIENT_ID=plane
PLANE_OIDC_CLIENT_SECRET=<위에서 복사한 값>
```

### 3단계: Plane에 OIDC 설정 입력

방법 1 (GodMode 사용):
- `https://lab.snu.ac.kr/god-mode` 접속
- Authentication > OIDC 메뉴
- 다음 입력:
  - Client ID: `plane`
  - Client Secret: (복사한 값)
  - Authorization URL: `https://auth.lab.snu.ac.kr/application/o/authorize/`
  - Token URL: `https://auth.lab.snu.ac.kr/application/o/token/`
  - Userinfo URL: `https://auth.lab.snu.ac.kr/application/o/userinfo/`

방법 2 (DB 직접):
GodMode가 없는 버전이면 환경변수로 설정:
```yaml
environment:
  OIDC_PROVIDER_NAME: Authentik
  OIDC_CLIENT_ID: ${PLANE_OIDC_CLIENT_ID}
  OIDC_CLIENT_SECRET: ${PLANE_OIDC_CLIENT_SECRET}
  OIDC_AUTHORIZATION_ENDPOINT: https://auth.lab.snu.ac.kr/application/o/authorize/
  OIDC_TOKEN_ENDPOINT: https://auth.lab.snu.ac.kr/application/o/token/
  OIDC_USERINFO_ENDPOINT: https://auth.lab.snu.ac.kr/application/o/userinfo/
```

### 4단계: 로그인 테스트

`https://lab.snu.ac.kr` 접속 → "Continue with OIDC" 버튼 → Authentik 로그인 페이지로 리다이렉트 → 인증 → Plane 복귀.

## Slack / GitHub 연동

Plane은 공식 integration 지원:

- Slack: Workspace Settings > Integrations > Slack
- GitHub: Workspace Settings > Integrations > GitHub
  - GitHub PAT 또는 GitHub App 설치
  - 양방향 sync (이슈 ↔ Plane work item)

## 백업 항목

| 데이터 | 위치 |
|---|---|
| DB | postgres `plane` DB |
| 첨부 파일 | MinIO `plane-uploads` 버킷 |
| 설정 | `.env`, `docker-compose.yml` |

## 트러블슈팅

**OIDC 로그인 후 무한 리다이렉트**:
- Redirect URI 끝에 `/` 누락 확인
- `WEB_URL` 환경변수가 정확한 도메인인지 확인
- 브라우저 쿠키 삭제

**파일 업로드 실패**:
- MinIO `plane-uploads` 버킷이 생성됐는지
- `AWS_S3_ENDPOINT_URL`이 컨테이너 네트워크 내 주소(`http://minio:9000`)인지

**worker가 작업 처리 안 함**:
- `docker logs plane-worker` 확인
- Redis 연결 (`REDIS_URL`)
- DB 마이그레이션 완료 여부 (`docker logs plane-api | grep migrate`)

## 업데이트

```bash
cd /srv/lab-platform/plane
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d

# 마이그레이션 자동 실행, 로그 확인
docker logs -f plane-api
```

메이저 버전 업데이트는 반드시 [공식 changelog](https://github.com/makeplane/plane/releases) 확인.
