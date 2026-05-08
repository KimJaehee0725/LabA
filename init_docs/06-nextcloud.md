# 06. Nextcloud + Collabora

파일 보관소 + 캘린더 + 공동 편집.

## 공식 자료

- 문서: https://docs.nextcloud.com/server/latest/admin_manual/
- 앱 스토어: https://apps.nextcloud.com/
- 한국 커뮤니티: https://nextcloud.kr (있는 경우)

## 첫 부팅

처음 컨테이너 시작 시 5~10분 소요. 로그 확인:
```bash
docker logs -f nextcloud
# "Initializing finished" 메시지 확인
```

이후 `https://files.lab.snu.ac.kr` 접속 → 자동 admin 로그인 (`.env`의 비밀번호).

## 필수 앱 설치

Settings > Apps에서 다음 검색·설치:

| 앱 | 용도 |
|---|---|
| Collabora Online (Built-in CODE) | 사용 안 함 (외부 Collabora 사용) |
| **Nextcloud Office** | Collabora WOPI 클라이언트 |
| **OpenID Connect Login** (또는 **OIDC Identity Provider**) | Authentik 연동 |
| **External user authentication** | (선택) |
| **Calendar** | 일정 |
| **Contacts** | 연락처 |
| **Notes** | 마크다운 노트 |
| **Tasks** | CalDAV 태스크 |
| **Group folders** | 그룹별 공유 폴더 |
| **Files Custom Viewer** | rhwp 통합용 (수동 설치) |

CLI 설치도 가능:
```bash
docker exec -u www-data nextcloud php occ app:install richdocuments
docker exec -u www-data nextcloud php occ app:install user_oidc
docker exec -u www-data nextcloud php occ app:install calendar
docker exec -u www-data nextcloud php occ app:install contacts
docker exec -u www-data nextcloud php occ app:install groupfolders
```

## Collabora 연동

### 1. Collabora 컨테이너 확인

```bash
docker ps | grep collabora
curl -k https://office.lab.snu.ac.kr/hosting/discovery
# XML 응답 확인
```

### 2. Nextcloud에서 연결

UI: Administration > Office (또는 Nextcloud Office)
- "Use your own server" 선택
- URL: `https://office.lab.snu.ac.kr`
- 저장

### 3. 테스트

Files에서 .docx 새로 만들기 → Collabora 에디터로 열림 → 편집 가능.

## Authentik OIDC 연동

### 사용 앱 결정

Nextcloud OIDC 옵션 두 가지:
- `user_oidc` (Nextcloud 공식, 권장)
- `oidc_login` (커뮤니티, 더 풍부한 기능)

`user_oidc` 권장.

### 1단계: Authentik 설정 확인

`02-authentik.md`의 nextcloud-provider:
- Client ID: `nextcloud`
- Redirect URI: `https://files.lab.snu.ac.kr/apps/user_oidc/code`

### 2단계: Nextcloud에서 OIDC Provider 추가

```bash
docker exec -u www-data nextcloud php occ user_oidc:provider \
    "Authentik" \
    --clientid="nextcloud" \
    --clientsecret="<authentik client secret>" \
    --discoveryuri="https://auth.lab.snu.ac.kr/application/o/nextcloud/.well-known/openid-configuration" \
    --scope="openid email profile" \
    --mapping-uid="sub" \
    --mapping-email="email" \
    --mapping-display-name="name" \
    --mapping-quota="" \
    --unique-uid=1
```

또는 UI: Settings > Administration > OpenID Connect

### 3단계: 자동 매핑

```bash
# 이메일 도메인 기반 자동 가입
docker exec -u www-data nextcloud php occ config:app:set user_oidc auto_provision --value=1
docker exec -u www-data nextcloud php occ config:app:set user_oidc soft_auto_provision --value=1
```

### 4단계: 로그인 테스트

`https://files.lab.snu.ac.kr` 로그인 페이지에 "Log in with Authentik" 버튼 표시. 클릭 → Authentik → Nextcloud 복귀.

## rhwp 통합 (Custom Viewer)

### 개념

Nextcloud에서 .hwp 파일 클릭 시 rhwp 뷰어를 모달로 띄우는 커스텀 앱 개발.

### 옵션 A: 단순 외부 링크 (가장 빠름)

`/srv/lab-platform/nextcloud/apps/rhwp_viewer/`에 간단한 앱 작성:

`appinfo/info.xml`:
```xml
<?xml version="1.0"?>
<info>
    <id>rhwp_viewer</id>
    <name>HWP Viewer (rhwp)</name>
    <summary>Open HWP/HWPX files with rhwp</summary>
    <description>Lab-internal viewer for HWP files using rhwp WASM</description>
    <version>0.1.0</version>
    <licence>MIT</licence>
    <author>Lab Platform</author>
    <namespace>RhwpViewer</namespace>
    <category>files</category>
    <bugs>https://hub.lab.snu.ac.kr/lab-code/rhwp_viewer/issues</bugs>
    <dependencies>
        <nextcloud min-version="28" max-version="30"/>
    </dependencies>
</info>
```

`js/main.js`:
```javascript
(function() {
    if (!OCA.Files) return;

    OCA.Files.fileActions.registerAction({
        name: 'OpenWithRhwp',
        displayName: 'Open with rhwp',
        mime: 'application/x-hwp',
        permissions: OC.PERMISSION_READ,
        icon: function() {
            return OC.imagePath('rhwp_viewer', 'hwp.svg');
        },
        actionHandler: function(filename, context) {
            var fileURL = context.fileList.getDownloadUrl(filename);
            // rhwp.lab.snu.ac.kr으로 파일 URL 전달
            window.open(
                'https://hwp.lab.snu.ac.kr/?file=' + encodeURIComponent(fileURL),
                '_blank'
            );
        }
    });

    // .hwpx도 추가
    OCA.Files.fileActions.registerAction({
        name: 'OpenWithRhwp',
        displayName: 'Open with rhwp',
        mime: 'application/x-hwpx',
        permissions: OC.PERMISSION_READ,
        icon: function() { return OC.imagePath('rhwp_viewer', 'hwp.svg'); },
        actionHandler: function(filename, context) {
            var fileURL = context.fileList.getDownloadUrl(filename);
            window.open('https://hwp.lab.snu.ac.kr/?file=' + encodeURIComponent(fileURL), '_blank');
        }
    });

    // MIME 등록 (Nextcloud는 .hwp를 octet-stream으로 처리)
    OC.MimeTypeList.fileTypes['hwp'] = 'application/x-hwp';
    OC.MimeTypeList.fileTypes['hwpx'] = 'application/x-hwpx';
})();
```

설치:
```bash
docker exec -u www-data nextcloud php occ app:enable rhwp_viewer
docker exec -u www-data nextcloud php occ maintenance:repair
```

rhwp 측 `index.html`에 `?file=` 파라미터 처리 코드 추가:
```javascript
const params = new URLSearchParams(location.search);
const fileUrl = params.get('file');
if (fileUrl) {
    fetch(fileUrl, { credentials: 'include' })
        .then(r => r.arrayBuffer())
        .then(buf => editor.loadFromBuffer(new Uint8Array(buf)));
}
```

### 옵션 B: 진짜 모달 통합 (Files Viewer API)

더 자연스러우나 개발 시간 큼. Nextcloud 30+의 Viewer API:

```javascript
OCA.Viewer.registerHandler({
    id: 'rhwp',
    group: 'documents',
    mimes: ['application/x-hwp', 'application/x-hwpx'],
    component: RhwpViewerComponent,
});
```

`RhwpViewerComponent`는 Vue 컴포넌트로 iframe 임베드:
```vue
<template>
    <iframe :src="iframeSrc" style="width:100%;height:100vh;border:0;"></iframe>
</template>
<script>
export default {
    props: ['source'],
    computed: {
        iframeSrc() {
            return `https://hwp.lab.snu.ac.kr/?file=${encodeURIComponent(this.source.source)}`;
        }
    }
}
</script>
```

처음엔 옵션 A로 시작 → 안정화되면 옵션 B로 발전.

## MinIO를 Primary Storage로 (선택)

대용량 파일 저장 시 MinIO 사용 권장:

```yaml
environment:
  OBJECTSTORE_S3_BUCKET: nextcloud-primary
  OBJECTSTORE_S3_HOST: minio
  OBJECTSTORE_S3_PORT: 9000
  OBJECTSTORE_S3_KEY: ${MINIO_ROOT_USER}
  OBJECTSTORE_S3_SECRET: ${MINIO_ROOT_PASSWORD}
  OBJECTSTORE_S3_USEPATH_STYLE: "true"
  OBJECTSTORE_S3_REGION: ${MINIO_REGION}
  OBJECTSTORE_S3_SSL: "false"
  OBJECTSTORE_S3_AUTOCREATE: "true"
```

**주의**: 한 번 결정하면 데이터 마이그레이션이 매우 어려움. 처음 셋업 때 결정 필요.

추천: **로컬 디스크로 시작**, 디스크 부족 시 새 인스턴스에 MinIO 백엔드로 마이그레이션.

## Group Folders

연구실용 공유 폴더:

UI: Administration > Group Folders > Create:
- `lab-shared` — 모든 멤버
- `lab-admin-only` — admin만
- `lab-projects/grpo-bsr` — 특정 프로젝트 그룹

권한:
- Quota: 100GB
- Permissions: Read/Write

## Cron 설정

Nextcloud는 cron 잡 필요 (이미 `nextcloud-cron` 컨테이너로 설정됨):

```bash
# 작동 확인
docker exec -u www-data nextcloud php occ background:cron
docker exec -u www-data nextcloud php occ background-job:list
```

UI: Administration > Basic settings > Background jobs → Cron 선택.

## 보안 강화

### Brute force protection

```bash
docker exec -u www-data nextcloud php occ config:app:set bruteforcesettings whitelist_0 --value="192.168.0.0/16"
```

### App passwords (학습 노드용)

WebDAV 접근 시 별도 비밀번호:
- 사용자 Settings > Security > App passwords > Create
- Username + 생성된 토큰을 학습 노드에 사용

```bash
# 학습 노드에서 WebDAV 마운트 (선택)
sudo apt install davfs2
echo "https://files.lab.snu.ac.kr/remote.php/dav/files/<user>/ <user> <app-password>" | sudo tee -a /etc/davfs2/secrets
sudo mount -t davfs https://files.lab.snu.ac.kr/remote.php/dav/files/<user>/ /mnt/lab-files
```

## 백업 항목

| 데이터 | 위치 | 중요도 |
|---|---|---|
| DB | postgres `nextcloud` DB | 매우 높음 |
| 사용자 데이터 | `/srv/lab-platform/nextcloud/data/data/` 또는 MinIO | 매우 높음 |
| 설정 | `/srv/lab-platform/nextcloud/data/html/config/config.php` | 높음 |
| 커스텀 앱 | `/srv/lab-platform/nextcloud/apps/` | 중간 |

```bash
# 유지보수 모드 (안전한 백업)
docker exec -u www-data nextcloud php occ maintenance:mode --on

# 백업 수행
tar -czf nextcloud-data.tar.gz /srv/lab-platform/nextcloud/data
docker exec postgres pg_dump -U postgres nextcloud | gzip > nextcloud-db.sql.gz

# 유지보수 모드 해제
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

매일 자동 백업 시 `maintenance:mode`를 매번 켜고 끄는 건 사용자 불편 → 새벽 시간대(3am)에 `mode --on` → 백업 → `mode --off` 순으로 cron 등록.

## 트러블슈팅

**"Untrusted domain" 에러**:
```bash
docker exec -u www-data nextcloud php occ config:system:set trusted_domains 1 --value="files.lab.snu.ac.kr"
```

**파일 업로드 실패 (큰 파일)**:
```bash
# php.ini 직접 수정 (컨테이너 내부)
docker exec nextcloud bash -c "echo 'upload_max_filesize = 10G' >> /usr/local/etc/php/conf.d/uploads.ini"
docker exec nextcloud bash -c "echo 'post_max_size = 10G' >> /usr/local/etc/php/conf.d/uploads.ini"
docker restart nextcloud
```

**Collabora 연결 실패**:
- `domain` 정규식 일치 확인 (escape 주의: `files\\.lab\\.snu\\.ac\\.kr`)
- `office.lab.snu.ac.kr/hosting/discovery` 직접 접속 테스트

**OIDC 로그인 후 사용자 생성 안 됨**:
```bash
docker exec -u www-data nextcloud php occ config:app:set user_oidc auto_provision --value=1
docker exec -u www-data nextcloud php occ user_oidc:provider --list
```

## 업데이트

Nextcloud는 한 단계씩만 마이너 업데이트 가능 (예: 28 → 29 → 30):

```bash
# 백업 먼저!
/srv/lab-platform/backups/scripts/00-backup-all.sh

# 이미지 태그 변경
sed -i 's/nextcloud:30/nextcloud:31/' /srv/lab-platform/nextcloud/docker-compose.yml

cd /srv/lab-platform/nextcloud
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d

# 자동 마이그레이션 (~10분)
docker logs -f nextcloud

# 수동 트리거 필요 시
docker exec -u www-data nextcloud php occ upgrade
```
