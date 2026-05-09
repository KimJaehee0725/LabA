# 07. Nextcloud and Collabora Module

## 모듈 목표

Nextcloud는 연구실 파일 보관, 캘린더, 연락처, 태스크, 그룹 폴더를 담당한다. v0.3 app wave에서는 단순 파일 저장소가 아니라 Notion 대체에 가까운 문서/연구 허브로 확장한다. Collabora는 Nextcloud Office를 통한 문서 공동 편집을 담당한다.

포함:

- Nextcloud compose
- Postgres 연동
- Redis lock/cache 후보
- Authentik OIDC via `user_oidc`
- Collabora compose
- Nginx routing
- app install script
- group folders 초안
- Collectives, Tables, Deck, Calendar/Tasks, GitHub integration
- document hub seed/check script

## 공식 문서 반영사항

Nextcloud 공식 문서는 외부 Identity Provider로 인증할 때 `user_oidc` 앱을 사용한다고 설명한다. Overwrite URL, trusted domains, reverse proxy 설정은 도메인 변경과 proxy 환경에서 중요하다. Collabora는 reverse proxy, WOPI allowlist, WebSocket alignment가 흔한 실패 지점이다.

v0.1 결정:

- v0.2 기본 storage는 로컬 data volume.
- Auth는 `user_oidc`.
- Collabora는 외부 CODE container를 사용하고, built-in CODE는 사용하지 않는다.
- HWP viewer는 v0.3 smoke 범위 밖.

## v0.2 산출물

```text
deploy/compose/nextcloud/docker-compose.yml
deploy/nginx/conf.d/50-nextcloud.conf
deploy/nginx/conf.d/60-collabora.conf
deploy/scripts/70-install-nextcloud-apps.sh
deploy/scripts/71-configure-nextcloud-oidc.sh
deploy/scripts/72-check-nextcloud.sh
deploy/runbooks/nextcloud-collabora.md
```

## 의존성

- Postgres DB: `nextcloud`
- Redis DB: `3`
- Nginx:
  - `files.lab.snu.ac.kr`
  - `office.lab.snu.ac.kr`
- Authentik OIDC provider: `nextcloud`
- Collabora container

## Storage 결정

v0.2 기본:

```text
/srv/lab-platform/data/nextcloud/data
```

MinIO primary storage는 v0.2 범위에서 제외한다.

이유:

- Nextcloud primary storage는 초기 결정 후 변경이 어렵다.
- v0.3 smoke에는 로컬 disk가 더 단순하다.
- 대용량 운영 요구가 확정되면 새 인스턴스 또는 migration plan으로 다룬다.

## 필수 앱

설치 목록:

```bash
occ app:install richdocuments
occ app:install user_oidc
occ app:install calendar
occ app:install contacts
occ app:install notes
occ app:install tasks
occ app:install groupfolders
occ app:install collectives
occ app:install tables
occ app:install deck
occ app:install integration_github
```

`richdocumentscode`는 사용하지 않는다.

## OIDC 계획

Authentik:

- Provider: `nextcloud-provider`
- Client ID: `nextcloud`
- Redirect URI: `https://files.lab.snu.ac.kr/apps/user_oidc/code`

Nextcloud:

```bash
occ user_oidc:provider "Authentik" \
  --clientid="nextcloud" \
  --clientsecret="<secret>" \
  --discoveryuri="https://auth.lab.snu.ac.kr/application/o/nextcloud/.well-known/openid-configuration" \
  --scope="openid email profile groups" \
  --mapping-uid="sub" \
  --mapping-email="email" \
  --mapping-display-name="name" \
  --unique-uid=1 \
  --group-provisioning=1 \
  --group-whitelist-regex='/^lab-(admin|member|collab|guest)$/' \
  --group-restrict-login-to-whitelist=1
```

주의:

- `oidc_login`용 callback과 혼동하지 않는다.
- 자동 provision 범위는 `lab-admin`, `lab-member`, `lab-collab`, `lab-guest`로 제한한다.

## Reverse proxy config

Nextcloud config.php 필수 후보:

```php
'trusted_domains' => ['files.lab.snu.ac.kr'],
'trusted_proxies' => ['nginx'],
'overwrite.cli.url' => 'https://files.lab.snu.ac.kr',
'overwriteprotocol' => 'https',
```

실제 Docker network IP range 또는 nginx container name에 맞춘다.

## Collabora 계획

Domain:

```text
office.lab.snu.ac.kr
```

Collabora env 후보:

```text
domain=files\\.lab\\.snu\\.ac\\.kr
extra_params=--o:ssl.enable=false --o:ssl.termination=true
```

Nextcloud Office 설정:

```text
Use your own server: https://office.lab.snu.ac.kr
```

검증:

```bash
curl -k https://office.lab.snu.ac.kr/hosting/discovery
```

주의:

- WOPI host mismatch가 흔하다.
- Collabora가 Nextcloud를 어떤 URL로 호출하는지 확인해야 한다.
- WebSocket proxy 설정이 필요하다.

## Group Folders

v0.3 seed:

| Folder | 대상 |
|---|---|
| `Lab Demo Documents` | `lab-member` |

하위 folder:

- `00-inbox`
- `01-meeting-notes`
- `02-literature`
- `03-slides`
- `04-reports`

초기 운영 후보:

| Folder | 대상 |
|---|---|
| `Lab Shared` | `lab-member` |
| `Lab Admin Only` | `lab-admin` |
| `Lab Projects` | 프로젝트별 세분화 |

권한:

- 초기 quota는 보수적으로 설정
- 외부 협업자는 project folder 단위로 부여

## Document Hub

v0.3 문서 허브 seed는 `deploy/data-model/lab-domain.v0.3.yaml`의 `nextcloud` 섹션을 기준으로 한다.

구성:

- Group folder: `Lab Demo Documents`
- Collectives: `Lab Knowledge Base`
- Pages: `Home`, `Research Onboarding`, `Meeting Notes`, `Experiment Log`, `Paper Reading`
- Tables: `Research Resources`
- Columns: title/type/owner/date/status/file link/GitHub link/tags
- Deck board: `Research Ops`
- Calendar: `research-demo`

Seed script:

```bash
NEXTCLOUD_SEED_APP_PASSWORD=<runtime app password> \
  /srv/lab-platform/scripts/73-seed-nextcloud-document-hub.sh
```

WebDAV/API credential은 runtime env에서만 읽고 출력하지 않는다. 가능하면 admin password 대신 app password를 쓴다.

## GitHub Integration

`integration_github`는 설치/활성화만 v0.3 pass 조건에 포함한다. GitHub PAT 또는 OAuth secret은 서버 env에 저장하지 않는다. 각 사용자가 Nextcloud Personal settings -> Connected accounts에서 연결한다.

## Cron

Nextcloud cron container를 둔다.

검증:

```bash
occ background:cron
occ background-job:list
```

UI에서 background jobs가 Cron으로 설정되어야 한다.

## HWP viewer 후속

v0.3 이후:

- `rhwp_viewer` Nextcloud app
- `hwp.lab.snu.ac.kr`
- 권한 있는 file URL 전달
- external share link와 인증 cookie 처리 검토

## 백업

대상:

- Postgres `nextcloud`
- Nextcloud data volume
- `config.php`
- custom apps
- groupfolders metadata

안전 백업:

```bash
occ maintenance:mode --on
pg_dump nextcloud
tar nextcloud data/config/custom_apps
occ maintenance:mode --off
```

## v0.3 Smoke

- OIDC login
- 파일 업로드
- 파일 다운로드
- group folder 접근
- Collectives landing page 접근
- Tables app에서 `Research Resources` 접근
- Deck에서 `Research Ops` board 접근
- docx 생성
- Collabora 편집 후 저장
- Calendar 접근
- app password 생성과 WebDAV 간단 테스트
- GitHub integration app enabled/provider presence 확인

## 위험

| 위험 | 대응 |
|---|---|
| OIDC callback 앱 혼동 | `user_oidc` 기준으로 문서/blueprint 통일 |
| domain 변경 어려움 | 도메인 placeholder를 변수화하고 실제 적용 전 확정 |
| Collabora WOPI 실패 | discovery, WebSocket, domain regex 체크리스트 |
| 큰 파일 upload 실패 | PHP/Nginx upload limit 동시 설정 |
| primary storage 변경 난이도 | v0.2에서는 로컬 disk 고정 |
