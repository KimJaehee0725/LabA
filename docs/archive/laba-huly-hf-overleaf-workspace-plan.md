# 연구실 통합 워크스페이스 구현 계획서

## 0. 프로젝트 개요

### 0.1 목표

기존에 사용하던 Notion을 자체 호스팅으로 전환하면서, 다음 기능들을 통합한 연구실 워크스페이스를 구축합니다.

- Notion 대체 (위키, 문서, 이슈 트래킹, 채팅, 캘린더, 간트 차트)
- GitHub / Slack 연동
- HuggingFace 스타일 모델/데이터셋 자체 호스팅
- Overleaf를 통한 LaTeX 논문 협업
- 외부에서도 학생들이 접근 가능한 공개 서비스

### 0.2 최종 아키텍처

```text
                    [학교 도메인: lab.snu.ac.kr 가정]
                           │
                       학교 DNS
                           │
                    학교 방화벽 (80/443 신청)
                           │
                    ┌──────▼──────┐
                    │   Nginx     │  Reverse Proxy + 학교 SSL
                    └──────┬──────┘
                           │
        ┌──────────┬───────┼───────┬──────────┐
        │          │       │       │          │
   [Authentik]  [Huly] [Overleaf] [MinIO]  [자체 HF UI]
    SSO/OIDC   메인허브  LaTeX    파일서버    모델/데이터셋
                                              │
                                         [자체 HDD]
```

### 0.3 서비스별 역할

| 서비스 | 역할 |
|--------|------|
| **Authentik** | 모든 서비스의 SSO 게이트웨이 (OIDC) |
| **Huly** | 위키/문서, 채팅, 이슈/Kanban/Calendar/Gantt, GitHub 양방향 연동 |
| **Overleaf CE** | LaTeX 논문 협업 |
| **MinIO** | S3 호환 객체 스토리지 (자체 HDD에 모델/데이터셋 저장) |
| **자체 HF-like UI** | MinIO 위에 올린 HuggingFace Hub 스타일 인터페이스 |
| **Nginx** | Reverse proxy + SSL 종단 |

---

## 1. 확정된 결정 사항

| 항목 | 결정 |
|------|------|
| 도메인 | 학교 도메인 사용 (단일 도메인) |
| HTTPS 인증서 | 학교 발급 인증서 사용 (와일드카드 가능) |
| 외부 접근 | 공개 (학생 외부 접속 가능) |
| 학교 방화벽 | 포트 신청 진행 (80, 443) |
| 외부 보고 | 의무 보고 없음 |
| SMTP | 학교 SMTP 사용 가능 |
| Gitea | 사용 안 함 |
| 게스트 가입 정책 | **옵션 C: 초대 링크 방식** + 가입 시 관리자에게 메일 알림 |
| 백업 | 매일 + 30일 보관, 별도 디스크에 이중화 |

### 1.1 도메인 구조

```text
lab.snu.ac.kr           포털 페이지
auth.lab.snu.ac.kr      Authentik
huly.lab.snu.ac.kr      Huly
overleaf.lab.snu.ac.kr  Overleaf CE
files.lab.snu.ac.kr     MinIO Console
s3.lab.snu.ac.kr        MinIO API (S3 endpoint)
hf.lab.snu.ac.kr        자체 HF-like UI
```

> 실제 도메인은 학교에서 발급받은 도메인으로 치환합니다.

---

## 2. Phase 1: 인프라 준비

### 2.1 사전 신청

행정실/정보화본부에 다음을 신청:

- [ ] 도메인 발급 (예: `lab.snu.ac.kr`)
- [ ] DNS A 레코드 등록 (서버 공인 IP)
- [ ] 와일드카드 SSL 인증서 발급 (`*.lab.snu.ac.kr` + `lab.snu.ac.kr`)
- [ ] 방화벽 인바운드 허용: TCP 80, 443
- [ ] 학교 SMTP 정보 수령 (서버 주소, 포트, 인증 방식)

### 2.2 서버 OS 셋업

```bash
# Ubuntu 24.04 LTS 기준
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  docker.io docker-compose-plugin \
  git curl wget \
  nginx \
  fail2ban \
  ufw \
  unattended-upgrades \
  rsync \
  rclone

sudo usermod -aG docker $USER
newgrp docker
```

### 2.3 SSH 보안

`/etc/ssh/sshd_config`:

```text
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

```bash
sudo systemctl restart ssh
```

각 멤버의 SSH 공개키를 `~/.ssh/authorized_keys`에 등록.

### 2.4 fail2ban

```bash
sudo cp /etc/fail2ban/jail.{conf,local}
```

`/etc/fail2ban/jail.local`에서 활성화:

- `[sshd]`
- `[nginx-http-auth]`
- `[nginx-limit-req]`
- `[nginx-botsearch]`

```bash
sudo systemctl enable --now fail2ban
```

### 2.5 방화벽 (서버 단)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 2.6 자동 보안 업데이트

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

`/etc/apt/apt.conf.d/50unattended-upgrades`에서 보안 업데이트 자동 적용 확인.

### 2.7 디렉토리 구조

```bash
sudo mkdir -p /opt/lab-stack/{authentik,huly,overleaf,minio,nginx,backups,certs,portal,hf-ui}
sudo mkdir -p /mnt/hdd/minio       # MinIO 데이터 저장 (실제 HDD 마운트)
sudo mkdir -p /mnt/backup/lab      # 백업용 별도 디스크 마운트
sudo chown -R $USER:$USER /opt/lab-stack
```

### 2.8 체크포인트

- [ ] Docker 정상 동작 (`docker run hello-world`)
- [ ] Nginx 기동 및 80/443 도달 확인
- [ ] SSH 키 인증만 작동 (비밀번호 막힘)
- [ ] fail2ban 상태 확인 (`fail2ban-client status`)
- [ ] HDD 마운트 정상 (`/mnt/hdd/minio`에 쓰기 가능)
- [ ] 백업 디스크 마운트 정상 (`/mnt/backup/lab`)

---

## 3. Phase 2: 학교 SSL 인증서 배치

### 3.1 인증서 파일 배치

학교에서 받은 파일을 다음 위치에 배치:

```text
/opt/lab-stack/certs/
├── lab.snu.ac.kr.crt        # 발급받은 인증서
├── lab.snu.ac.kr.key        # 개인키 (권한 600)
├── ca-bundle.crt            # 중간/루트 인증서 체인
└── fullchain.crt            # crt + ca-bundle 합친 파일
```

### 3.2 fullchain 생성

```bash
cd /opt/lab-stack/certs
cat lab.snu.ac.kr.crt ca-bundle.crt > fullchain.crt
chmod 644 fullchain.crt
chmod 600 lab.snu.ac.kr.key
```

### 3.3 만료 알림 설정

`/opt/lab-stack/scripts/check-cert-expiry.sh`:

```bash
#!/bin/bash
CERT=/opt/lab-stack/certs/lab.snu.ac.kr.crt
DAYS_LEFT=$(( ($(date -d "$(openssl x509 -enddate -noout -in $CERT | cut -d= -f2)" +%s) - $(date +%s)) / 86400 ))

if [ $DAYS_LEFT -lt 30 ]; then
  echo "[WARN] 인증서 만료까지 ${DAYS_LEFT}일 남음" | \
    mail -s "[Lab] SSL 인증서 갱신 필요" admin@lab.snu.ac.kr
fi
```

cron 등록 (매일 09:00):

```text
0 9 * * * /opt/lab-stack/scripts/check-cert-expiry.sh
```

### 3.4 갱신 절차 문서화

매년 인증서 갱신 시 절차를 README에 명시:

1. 학교에서 신규 인증서 수령
2. `/opt/lab-stack/certs/`의 파일 교체
3. `cat`으로 fullchain 재생성
4. `sudo systemctl reload nginx`
5. 브라우저에서 만료일 확인

### 3.5 체크포인트

- [ ] 인증서 파일 배치 완료, 권한 설정 정상
- [ ] `openssl x509 -in fullchain.crt -text -noout`로 체인 검증
- [ ] 만료일 자동 점검 cron 등록

---

## 4. Phase 3: Nginx Reverse Proxy 골격

### 4.1 공통 보안 설정

`/etc/nginx/conf.d/00-security.conf`:

```nginx
# Rate limiting
limit_req_zone $binary_remote_addr zone=general:10m rate=30r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/s;

# Hide version
server_tokens off;

# Body size (모델 업로드 대비)
client_max_body_size 10G;

# Timeout
proxy_connect_timeout 60s;
proxy_send_timeout 600s;
proxy_read_timeout 600s;

# SSL 공통
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
```

### 4.2 보안 헤더 (별도 파일)

`/etc/nginx/snippets/security-headers.conf`:

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(self), geolocation=()" always;
```

각 서비스 conf에서 `include snippets/security-headers.conf;`로 사용.

### 4.3 80 → 443 리다이렉트

`/etc/nginx/sites-available/00-redirect.conf`:

```nginx
server {
    listen 80;
    server_name lab.snu.ac.kr *.lab.snu.ac.kr;
    return 301 https://$host$request_uri;
}
```

### 4.4 SSL 공통 include

`/etc/nginx/snippets/ssl-school.conf`:

```nginx
ssl_certificate /opt/lab-stack/certs/fullchain.crt;
ssl_certificate_key /opt/lab-stack/certs/lab.snu.ac.kr.key;
```

### 4.5 서비스별 conf 템플릿

각 서브도메인은 다음 패턴을 따름:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name {service}.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    location / {
        proxy_pass http://127.0.0.1:{port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 지원 (Huly, Overleaf 필수)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 4.6 체크포인트

- [ ] `nginx -t` 통과
- [ ] HTTP → HTTPS 리다이렉트 동작
- [ ] SSL Labs 등에서 A 등급 (학교 인증서 기준 최선)

---

## 5. Phase 4: Authentik (SSO/OIDC)

### 5.1 docker-compose.yml

`/opt/lab-stack/authentik/docker-compose.yml`:

```yaml
version: "3.4"

services:
  postgresql:
    image: docker.io/library/postgres:16-alpine
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 5s
    volumes:
      - database:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: ${PG_PASS}
      POSTGRES_USER: ${PG_USER:-authentik}
      POSTGRES_DB: ${PG_DB:-authentik}

  redis:
    image: docker.io/library/redis:alpine
    command: --save 60 1 --loglevel warning
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "redis-cli ping | grep PONG"]
      start_period: 20s
      interval: 30s
      retries: 5
      timeout: 3s
    volumes:
      - redis:/data

  server:
    image: ghcr.io/goauthentik/server:latest
    restart: unless-stopped
    command: server
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_ERROR_REPORTING__ENABLED: "false"
      AUTHENTIK_EMAIL__HOST: ${SMTP_HOST}
      AUTHENTIK_EMAIL__PORT: ${SMTP_PORT}
      AUTHENTIK_EMAIL__USERNAME: ${SMTP_USER}
      AUTHENTIK_EMAIL__PASSWORD: ${SMTP_PASS}
      AUTHENTIK_EMAIL__USE_TLS: "true"
      AUTHENTIK_EMAIL__FROM: ${SMTP_FROM}
    volumes:
      - ./media:/media
      - ./custom-templates:/templates
    ports:
      - "127.0.0.1:9000:9000"
    depends_on:
      - postgresql
      - redis

  worker:
    image: ghcr.io/goauthentik/server:latest
    restart: unless-stopped
    command: worker
    environment:
      AUTHENTIK_REDIS__HOST: redis
      AUTHENTIK_POSTGRESQL__HOST: postgresql
      AUTHENTIK_POSTGRESQL__USER: ${PG_USER:-authentik}
      AUTHENTIK_POSTGRESQL__NAME: ${PG_DB:-authentik}
      AUTHENTIK_POSTGRESQL__PASSWORD: ${PG_PASS}
      AUTHENTIK_SECRET_KEY: ${AUTHENTIK_SECRET_KEY}
      AUTHENTIK_EMAIL__HOST: ${SMTP_HOST}
      AUTHENTIK_EMAIL__PORT: ${SMTP_PORT}
      AUTHENTIK_EMAIL__USERNAME: ${SMTP_USER}
      AUTHENTIK_EMAIL__PASSWORD: ${SMTP_PASS}
      AUTHENTIK_EMAIL__USE_TLS: "true"
      AUTHENTIK_EMAIL__FROM: ${SMTP_FROM}
    user: root
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./media:/media
      - ./certs:/certs
      - ./custom-templates:/templates
    depends_on:
      - postgresql
      - redis

volumes:
  database:
  redis:
```

### 5.2 .env

```bash
cd /opt/lab-stack/authentik
cat > .env <<EOF
PG_PASS=$(openssl rand -base64 36 | tr -d '\n')
AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')

SMTP_HOST=학교_SMTP_서버
SMTP_PORT=587
SMTP_USER=학교_계정
SMTP_PASS=학교_비밀번호
SMTP_FROM=lab-noreply@snu.ac.kr
EOF
chmod 600 .env
```

### 5.3 기동

```bash
cd /opt/lab-stack/authentik
docker compose up -d
```

### 5.4 Nginx conf

`/etc/nginx/sites-available/auth.conf`:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name auth.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/v3/ {
        limit_req zone=login burst=10 nodelay;
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 5.5 초기 설정

1. `https://auth.lab.snu.ac.kr/if/flow/initial-setup/` 접속
2. 관리자 계정 생성 (admin@lab.snu.ac.kr 등)
3. 로그인 후 다음 작업:

#### 5.5.1 그룹 생성

- `lab-admins` (관리자)
- `lab-members` (정식 멤버, 학생/연구원)
- `lab-guests` (외부 협업자)

#### 5.5.2 2FA 의무화

- Stages → Authenticator TOTP Setup Stage 생성
- Default Authentication Flow에 binding (모든 로그인 시 2FA 요구)
- 외부 공개 환경이므로 필수

#### 5.5.3 Captcha 추가

- Stages → Captcha Stage 생성
- 회원가입/비밀번호 리셋 flow에 binding

#### 5.5.4 신규 가입 정책 (옵션 C: 초대 링크 방식)

**자가 가입은 비활성화하고, 초대 링크 발급 흐름 구성:**

1. **Default Enrollment Flow를 비활성화** 또는 unauthenticated 접근 차단
2. **Invitations 기능 활성화**:
   - Directory → Invitations
   - 멤버가 게스트 초대 시 invitation 토큰 발급
   - 토큰 포함 URL을 게스트에게 메일로 전달
3. **초대 받은 사용자만 enrollment flow 통과 가능**하도록 정책 설정

#### 5.5.5 가입 알림 (관리자에게 메일 발송)

Authentik의 Notification 기능 활용:

1. **Events → Notifications → Transports**에서 "Email" transport 생성
   - To: `admin@lab.snu.ac.kr` (실제 운영자 메일)
2. **Events → Notifications → Rules** 생성
   - Trigger event: `model_created`
   - Filter: User 모델만
   - Severity: notice
   - Group: lab-admins
3. 신규 가입자가 enrollment flow를 완료할 때마다 운영자 메일로 자동 알림 발송

> 추가로 enrollment flow 끝에 `Notification Stage`를 직접 binding하는 방법도 가능. 기본 정책으로 안 잡히면 이쪽 사용.

### 5.6 OIDC Provider 사전 생성

각 서비스용 OIDC Provider를 미리 만들어둠:

| 이름 | Redirect URI |
|------|--------------|
| huly-oidc | `https://huly.lab.snu.ac.kr/api/v1/oidc/callback` |
| minio-oidc | `https://files.lab.snu.ac.kr/oauth_callback` |
| overleaf-oidc | `https://overleaf.lab.snu.ac.kr/oauth/callback` (지원 시) |
| hf-ui-oidc | `https://hf.lab.snu.ac.kr/api/auth/callback/authentik` |
| portal-oidc | `https://lab.snu.ac.kr/auth/callback` |

각 Provider에서 client_id, client_secret을 받아 보관.

### 5.7 체크포인트

- [ ] `https://auth.lab.snu.ac.kr` 접속, 학교 인증서 정상
- [ ] 관리자 로그인 + 2FA 등록 정상
- [ ] 테스트 사용자 1명 생성, 메일 인증 진행
- [ ] 초대 링크 발급 → 게스트 가입 흐름 테스트
- [ ] 게스트 가입 시 운영자 메일 수신 확인
- [ ] OIDC Provider 5개 생성, client 정보 보관

---

## 6. Phase 5: Huly (메인 허브)

### 6.1 설치

```bash
cd /opt/lab-stack/huly
git clone https://github.com/hcengineering/huly-selfhost.git .
./setup.sh
```

setup 시 입력:

- HOST_ADDRESS: `huly.lab.snu.ac.kr`
- SECURE: `true`
- HTTP_PORT: `8087` (내부)

### 6.2 기동

```bash
docker compose up -d
# 약 60초 대기 후 접속 가능
```

### 6.3 Nginx conf

`/etc/nginx/sites-available/huly.conf`:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name huly.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    client_max_body_size 5G;

    location / {
        proxy_pass http://127.0.0.1:8087;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 필수
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # 실시간 협업용 long polling
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

### 6.4 워크스페이스 초기 설정

1. 첫 로그인 → 관리자 계정 생성
2. 워크스페이스 생성: `lab`
3. 채널 생성:
   - `#general` (전체 공지)
   - `#research` (연구 토론)
   - `#paper` (논문 작업)
   - `#infra` (서버/인프라)
   - `#random` (잡담)
4. 프로젝트 생성:
   - `Experiments` (실험 트래킹)
   - `Papers` (논문 작업)
   - `Infrastructure` (서버/인프라 관리)

### 6.5 SSO 연동 (Authentik OIDC)

> ⚠️ Huly self-host의 OIDC 지원 상태가 버전마다 다름. 공식 문서 우선 확인.
> 미지원 시 Nginx 앞단에서 Authentik forward-auth로 보호하는 방식으로 우회.

지원 시:

1. Huly Admin → SSO 설정
2. Authentik Provider 정보 입력 (client_id, client_secret, issuer URL)
3. 테스트 로그인

### 6.6 GitHub 양방향 연동

#### 6.6.1 GitHub App 생성

1. GitHub 조직 → Settings → Developer settings → GitHub Apps → New
2. Webhook URL: `https://huly.lab.snu.ac.kr/api/v1/github/webhook`
3. 권한 설정:
   - Issues: Read & write
   - Pull requests: Read & write
   - Metadata: Read
   - Repository contents: Read
4. App ID, Private Key (PEM), Webhook Secret 받기

#### 6.6.2 Huly에 등록

- App ID, Private Key, Webhook Secret을 Huly 환경변수 또는 UI에 등록
- 연결할 repository 선택
- 양방향 sync 테스트:
  - Huly에서 이슈 생성 → GitHub에 같은 이슈 생성됨
  - GitHub에서 PR 머지 → Huly 이슈 상태 자동 변경

### 6.7 Slack 연동 (병행 운영 시)

기존 Slack을 당분간 유지하면서 Huly로 점진 이전:

```text
GitHub PR/이슈 알림   → 기존 Slack (그대로 유지)
Huly 이슈 변경 알림   → Slack webhook으로 전달
연구실 내부 토론      → Huly로 이전
```

Huly Webhook 설정:

- Huly 프로젝트 → Settings → Webhooks
- Slack Incoming Webhook URL 등록

### 6.8 Gantt View 검증 (중요)

Huly self-hosted 버전에서 Gantt가 실제 동작하는지 확인:

1. 프로젝트 생성, 이슈 여러 개 만들기
2. 시작일/종료일 설정
3. View → Timeline/Gantt 전환
4. 정상 렌더링 확인

> Gantt가 self-hosted에서 미동작하면 Plane을 추가 배포하는 옵션 검토 (별도 이슈로 처리).

### 6.9 체크포인트

- [ ] Huly 웹 UI 접속 정상, 학교 인증서 적용
- [ ] 멤버 초대 메일 발송 정상
- [ ] 채팅, 문서, 이슈, 캘린더 모두 정상 동작
- [ ] **Gantt view self-hosted 동작 확인**
- [ ] GitHub repo 연결, 이슈 양방향 sync 검증
- [ ] Slack webhook 알림 정상

---

## 7. Phase 6: MinIO (객체 스토리지)

### 7.1 docker-compose.yml

`/opt/lab-stack/minio/docker-compose.yml`:

```yaml
version: "3.8"

services:
  minio:
    image: minio/minio:latest
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
      MINIO_BROWSER_REDIRECT_URL: https://files.lab.snu.ac.kr
      MINIO_SERVER_URL: https://s3.lab.snu.ac.kr

      # OIDC 연동 (Authentik)
      MINIO_IDENTITY_OPENID_CONFIG_URL: https://auth.lab.snu.ac.kr/application/o/minio-oidc/.well-known/openid-configuration
      MINIO_IDENTITY_OPENID_CLIENT_ID: ${OIDC_CLIENT_ID}
      MINIO_IDENTITY_OPENID_CLIENT_SECRET: ${OIDC_CLIENT_SECRET}
      MINIO_IDENTITY_OPENID_DISPLAY_NAME: "Lab SSO"
      MINIO_IDENTITY_OPENID_SCOPES: "openid,profile,email,groups"
      MINIO_IDENTITY_OPENID_REDIRECT_URI: https://files.lab.snu.ac.kr/oauth_callback
      MINIO_IDENTITY_OPENID_CLAIM_NAME: groups
    volumes:
      - /mnt/hdd/minio:/data
    ports:
      - "127.0.0.1:9000:9000"   # API (S3)
      - "127.0.0.1:9001:9001"   # Console
```

### 7.2 .env

```bash
cat > /opt/lab-stack/minio/.env <<EOF
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')
OIDC_CLIENT_ID=Authentik에서_받은_값
OIDC_CLIENT_SECRET=Authentik에서_받은_값
EOF
chmod 600 /opt/lab-stack/minio/.env
```

### 7.3 Nginx conf (Console + API 분리)

`/etc/nginx/sites-available/minio.conf`:

```nginx
# MinIO Console (웹 UI)
server {
    listen 443 ssl;
    http2 on;
    server_name files.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    client_max_body_size 0;
    chunked_transfer_encoding on;

    location / {
        proxy_pass http://127.0.0.1:9001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# MinIO API (S3 endpoint)
server {
    listen 443 ssl;
    http2 on;
    server_name s3.lab.snu.ac.kr;

    include snippets/ssl-school.conf;

    client_max_body_size 0;
    chunked_transfer_encoding on;
    ignore_invalid_headers off;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 300;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

### 7.4 버킷 구조 설계

```text
s3://lab-models/        # 학습된 모델 weight
   └── {user}/{model-name}/{version}/
s3://lab-datasets/      # 데이터셋
   └── {dataset-name}/{version}/
s3://lab-artifacts/     # 실험 결과 (wandb 대체 가능)
   └── {experiment-id}/
s3://lab-public/        # 외부 공유용 (read-only public)
s3://lab-backups/       # 다른 서비스의 백업 저장소
```

각 버킷에:

- Versioning 활성화
- Object lock (선택, 중요 모델용)

### 7.5 정책 (Policy) 설정

기본 정책:

- `lab-admins` 그룹: 모든 버킷 read/write
- `lab-members` 그룹: `lab-models`, `lab-datasets`, `lab-artifacts` read/write, `lab-public` read
- `lab-guests` 그룹: `lab-public` read만

### 7.6 HuggingFace 호환 사용 가이드

연구실 멤버용 사용법 문서 작성 (Huly 위키에 게시):

```python
# 모델 업로드 예시
from huggingface_hub import HfApi

api = HfApi(endpoint="https://hf.lab.snu.ac.kr")  # 자체 HF UI 경유
# 또는 직접 boto3로 MinIO 접근
import boto3
s3 = boto3.client(
    's3',
    endpoint_url='https://s3.lab.snu.ac.kr',
    aws_access_key_id='YOUR_KEY',
    aws_secret_access_key='YOUR_SECRET'
)
s3.upload_file('model.safetensors', 'lab-models', 'jaehee/grpo-qwen-1.5b/v1/model.safetensors')
```

### 7.7 체크포인트

- [ ] `https://files.lab.snu.ac.kr` Console 접속, SSO 로그인 정상
- [ ] `https://s3.lab.snu.ac.kr` API endpoint 정상 (`mc alias` 등록 후 `mc ls` 작동)
- [ ] HDD 경로(`/mnt/hdd/minio`)에 실제 파일 저장 확인
- [ ] 4개 버킷 생성, 정책 적용
- [ ] boto3 또는 mc로 업/다운 테스트

---

## 8. Phase 7: 자체 HuggingFace-like UI

### 8.1 기술 스택 결정

| 영역 | 선택 |
|------|------|
| Frontend | Next.js 14 + TypeScript + shadcn/ui + Tailwind |
| Backend | FastAPI (Python) |
| Auth | Authentik OIDC (next-auth or python-jose) |
| Storage | MinIO (boto3 / aiobotocore) |
| Metadata DB | PostgreSQL (모델/데이터셋 메타정보) |

### 8.2 디렉토리 구조

```text
/opt/lab-stack/hf-ui/
├── frontend/          # Next.js
├── backend/           # FastAPI
├── docker-compose.yml
└── .env
```

### 8.3 MVP 기능 (Week 1~2)

- [ ] 로그인 (Authentik OIDC)
- [ ] 모델 리스트 페이지 (`/models`)
- [ ] 모델 상세 페이지 (`/models/{user}/{name}`)
  - README.md 렌더링 (markdown + LaTeX 수식 지원)
  - 파일 트리
  - 파일 다운로드 (presigned URL)
- [ ] 데이터셋 리스트/상세 (`/datasets/...`)
- [ ] 검색 (이름/태그 기반)

### 8.4 v1 기능 (Week 3~4)

- [ ] 업로드 UI
  - 큰 파일 multipart upload
  - 폴더 단위 업로드
  - 진행률 표시
- [ ] 메타데이터 편집
  - model card (README.md)
  - tags, license, base model
- [ ] 버전 관리 (git tag-like)
- [ ] 권한 관리 (private/public/group)

### 8.5 v2 기능 (선택, Week 5+)

- [ ] HuggingFace `huggingface_hub` 라이브러리 호환 API
  - `model.push_to_hub()`, `from_pretrained()` 작동
  - `/api/models`, `/api/datasets` 등 HF Hub API 흉내
- [ ] 모델 카드 자동 생성 (config.json 파싱)
- [ ] 좋아요/북마크
- [ ] 활동 피드

### 8.6 데이터 모델 (메타DB)

```sql
CREATE TABLE models (
    id UUID PRIMARY KEY,
    owner VARCHAR(100),       -- user or group name
    name VARCHAR(200),
    visibility VARCHAR(20),   -- public/private/group
    description TEXT,
    tags TEXT[],
    base_model VARCHAR(200),
    license VARCHAR(50),
    created_at TIMESTAMP,
    updated_at TIMESTAMP,
    storage_path TEXT,        -- s3://lab-models/...
    UNIQUE(owner, name)
);

CREATE TABLE model_versions (
    id UUID PRIMARY KEY,
    model_id UUID REFERENCES models(id),
    version VARCHAR(50),
    commit_message TEXT,
    files JSONB,              -- 파일 목록 + 크기 + 해시
    created_at TIMESTAMP,
    created_by VARCHAR(100)
);

-- datasets도 동일 구조
```

### 8.7 Nginx conf

`/etc/nginx/sites-available/hf-ui.conf`:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name hf.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    client_max_body_size 50G;  # 큰 모델 업로드

    location / {
        proxy_pass http://127.0.0.1:3000;  # Next.js
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000;  # FastAPI
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_request_buffering off;  # 큰 업로드 streaming
        proxy_read_timeout 3600s;
    }
}
```

### 8.8 체크포인트 (MVP 기준)

- [ ] 로그인 → 모델 리스트 → 상세 → 다운로드 플로우 완성
- [ ] 멤버 등급별 권한 동작 (private 모델 접근 차단 등)
- [ ] README.md 렌더링 (LaTeX 수식 포함)
- [ ] presigned URL 만료 동작 확인

---

## 9. Phase 8: Overleaf CE

### 9.1 설치

```bash
cd /opt/lab-stack/overleaf
git clone https://github.com/overleaf/toolkit.git .
bin/init
```

### 9.2 config/overleaf.rc 편집

```bash
OVERLEAF_LISTEN_IP=127.0.0.1
OVERLEAF_PORT=8090
OVERLEAF_DATA_PATH=/opt/lab-stack/overleaf/data
OVERLEAF_IS_BEHIND_PROXY=true
```

### 9.3 config/variables.env 편집

```bash
OVERLEAF_SITE_URL=https://overleaf.lab.snu.ac.kr
OVERLEAF_APP_NAME=Lab Overleaf
OVERLEAF_NAV_TITLE=Lab Overleaf

# 외부 가입 차단
OVERLEAF_ALLOW_PUBLIC_ACCESS=false
OVERLEAF_NEW_USER_REGISTRATION=false

# SMTP
OVERLEAF_EMAIL_FROM_ADDRESS=overleaf@lab.snu.ac.kr
OVERLEAF_EMAIL_SMTP_HOST=학교_SMTP
OVERLEAF_EMAIL_SMTP_PORT=587
OVERLEAF_EMAIL_SMTP_SECURE=false
OVERLEAF_EMAIL_SMTP_USER=학교_계정
OVERLEAF_EMAIL_SMTP_PASS=학교_비밀번호
```

### 9.4 기동

```bash
bin/up -d
# TeX Live 전체 설치 시 30분~1시간 소요
```

### 9.5 TeX Live full 설치

```bash
docker exec sharelatex tlmgr update --self
docker exec sharelatex tlmgr install scheme-full
```

### 9.6 Nginx conf

`/etc/nginx/sites-available/overleaf.conf`:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name overleaf.lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    client_max_body_size 200M;

    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600s;
    }
}
```

### 9.7 관리자 계정 + 사용자 생성

```bash
# 관리자
docker exec sharelatex grunt user:create-admin --email=admin@lab.snu.ac.kr

# 일반 사용자 (학생당 직접 발급, 또는 학생이 가입 신청 후 관리자가 생성)
docker exec sharelatex grunt user:create --email=student@snu.ac.kr
```

### 9.8 LaTeX 템플릿 미리 등록

자주 쓰는 학회 템플릿을 공용 프로젝트로 등록:

- NeurIPS
- ICML
- ICLR
- ACL/EMNLP
- AAAI

### 9.9 SSO 처리 방안

Overleaf CE는 OIDC 직접 지원 약함. 다음 중 선택:

**방안 1: 별도 계정 (가장 단순)**

- Authentik과 동일 이메일로 Overleaf 계정 별도 발급
- 사용자는 한 번 더 로그인 필요

**방안 2: Authentik LDAP outpost + Overleaf LDAP**

- Authentik이 LDAP 서버 역할
- Overleaf LDAP 모듈 사용
- 추가 설정 부담 있음

초기에는 **방안 1**로 시작 권장.

### 9.10 체크포인트

- [ ] PDF 컴파일 정상
- [ ] 협업 편집 정상 (2명 이상 동시 접속 테스트)
- [ ] NeurIPS/ICML 템플릿 컴파일 검증
- [ ] 한글 LaTeX 패키지(kotex 등) 동작 확인

---

## 10. Phase 9: 포털 페이지

### 10.1 목적

`https://lab.snu.ac.kr` 루트에 단순 포털 페이지로 모든 서비스 링크 제공.

### 10.2 구현 옵션

**옵션 A: 정적 HTML (가장 단순)**

`/opt/lab-stack/portal/index.html`:

- 로고, 서비스 카드 6개
- 클릭 시 각 서브도메인으로 이동
- Nginx에서 직접 서빙

**옵션 B: Homarr (대시보드)**

- 위젯, 헬스체크 표시
- Docker 1개로 실행

**옵션 C: Next.js 페이지 (HF UI와 통합)**

- HF-like UI 프로젝트의 홈페이지로 흡수
- 가장 통합된 느낌

초기에는 **옵션 A**로 시작, 나중에 C로 통합 권장.

### 10.3 Nginx conf

`/etc/nginx/sites-available/portal.conf`:

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name lab.snu.ac.kr;

    include snippets/ssl-school.conf;
    include snippets/security-headers.conf;

    root /opt/lab-stack/portal;
    index index.html;
}
```

### 10.4 체크포인트

- [ ] 루트 도메인 접속 시 포털 페이지 표시
- [ ] 모든 서비스 링크 정상 동작

---

## 11. Phase 10: 백업

### 11.1 백업 대상 정리

| 서비스 | 데이터 | 위치 | 방식 |
|--------|--------|------|------|
| Authentik | PostgreSQL | docker volume `authentik_database` | `pg_dump` |
| Huly | MongoDB + MinIO files + Elasticsearch | docker volumes | `mongodump` + `mc mirror` + ES snapshot |
| Overleaf | MongoDB + Redis + 프로젝트 파일 | docker volumes | `mongodump` + 디렉토리 tar |
| MinIO (lab data) | 모델/데이터셋 | `/mnt/hdd/minio` | `rclone sync` 증분 |
| Nginx 설정 | conf 파일 | `/etc/nginx/` | tar |
| 인증서 | crt/key | `/opt/lab-stack/certs/` | tar (암호화 권장) |

### 11.2 디렉토리 구조

```text
/opt/lab-stack/backups/
├── scripts/
│   ├── backup-all.sh
│   ├── backup-authentik.sh
│   ├── backup-huly.sh
│   ├── backup-overleaf.sh
│   ├── backup-minio.sh
│   ├── backup-nginx.sh
│   └── rotate.sh
├── logs/
└── README.md

/mnt/backup/lab/
├── daily/             # 30일 보관
│   └── YYYY-MM-DD/
└── weekly/            # 12주 보관
    └── YYYY-WW/
```

### 11.3 마스터 스크립트

`/opt/lab-stack/backups/scripts/backup-all.sh`:

```bash
#!/bin/bash
set -e

DATE=$(date +%Y-%m-%d)
BACKUP_DIR=/mnt/backup/lab/daily/$DATE
LOG=/opt/lab-stack/backups/logs/$DATE.log
ADMIN_MAIL=admin@lab.snu.ac.kr

mkdir -p $BACKUP_DIR

{
  echo "=== Backup started: $(date) ==="

  /opt/lab-stack/backups/scripts/backup-authentik.sh $BACKUP_DIR
  /opt/lab-stack/backups/scripts/backup-huly.sh $BACKUP_DIR
  /opt/lab-stack/backups/scripts/backup-overleaf.sh $BACKUP_DIR
  /opt/lab-stack/backups/scripts/backup-minio.sh $BACKUP_DIR
  /opt/lab-stack/backups/scripts/backup-nginx.sh $BACKUP_DIR

  /opt/lab-stack/backups/scripts/rotate.sh

  echo "=== Backup finished: $(date) ==="
} >> $LOG 2>&1

if [ $? -ne 0 ]; then
  tail -50 $LOG | mail -s "[Lab] 백업 실패 $DATE" $ADMIN_MAIL
fi
```

### 11.4 개별 스크립트 예시

`backup-authentik.sh`:

```bash
#!/bin/bash
BACKUP_DIR=$1
docker exec authentik-postgresql-1 \
  pg_dump -U authentik authentik | gzip > $BACKUP_DIR/authentik-db.sql.gz
```

`backup-huly.sh`:

```bash
#!/bin/bash
BACKUP_DIR=$1
mkdir -p $BACKUP_DIR/huly
# MongoDB
docker exec huly-mongodb mongodump --archive | gzip > $BACKUP_DIR/huly/mongo.gz
# MinIO files
docker exec huly-minio mc mirror /data $BACKUP_DIR/huly/files
```

`backup-minio.sh` (lab 데이터):

```bash
#!/bin/bash
BACKUP_DIR=$1
# rclone 설정 필요 (~/.config/rclone/rclone.conf)
rclone sync /mnt/hdd/minio $BACKUP_DIR/minio --progress
```

`rotate.sh`:

```bash
#!/bin/bash
# 30일 이상된 daily 백업 삭제
find /mnt/backup/lab/daily -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
# 12주 이상된 weekly 백업 삭제
find /mnt/backup/lab/weekly -maxdepth 1 -type d -mtime +84 -exec rm -rf {} \;
```

### 11.5 cron 등록

`/etc/cron.d/lab-backup`:

```text
# 매일 03:00 전체 백업
0 3 * * *  jaehee  /opt/lab-stack/backups/scripts/backup-all.sh

# 매주 일요일 04:00 weekly 스냅샷
0 4 * * 0  jaehee  cp -r /mnt/backup/lab/daily/$(date +\%Y-\%m-\%d) /mnt/backup/lab/weekly/$(date +\%Y-\%U)
```

### 11.6 복구 절차 문서화

`/opt/lab-stack/backups/README.md`에 각 서비스별 복구 명령 정리:

- Authentik DB 복구: `gunzip < authentik-db.sql.gz | docker exec -i authentik-postgresql-1 psql -U authentik`
- Huly MongoDB 복구: `gunzip < mongo.gz | docker exec -i huly-mongodb mongorestore --archive`
- 등등

### 11.7 월 1회 복구 테스트

매달 1일에 자동 알림:

- 백업 파일 1개를 별도 테스트 디렉토리에 복구
- 정상 복구 여부 확인 후 운영자 메일 발송

### 11.8 체크포인트

- [ ] 첫 백업 정상 실행, `/mnt/backup/lab/daily/`에 파일 생성
- [ ] 각 서비스별 복구 1회 테스트 완료
- [ ] cron 등록 후 다음날 자동 실행 확인
- [ ] 백업 실패 시 메일 알림 동작

---

## 12. Phase 11: 모니터링

### 12.1 Uptime Kuma

`/opt/lab-stack/monitoring/docker-compose.yml`:

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    restart: unless-stopped
    volumes:
      - ./data:/app/data
    ports:
      - "127.0.0.1:3001:3001"
```

서브도메인 `status.lab.snu.ac.kr` 추가 (선택), 또는 운영자 전용으로 내부에서만 접근.

### 12.2 모니터링 대상

| 서비스 | 헬스체크 |
|--------|---------|
| Authentik | `https://auth.lab.snu.ac.kr/-/health/live/` |
| Huly | `https://huly.lab.snu.ac.kr/api/v1/health` |
| Overleaf | `https://overleaf.lab.snu.ac.kr/status` |
| MinIO | `https://s3.lab.snu.ac.kr/minio/health/live` |
| HF UI | `https://hf.lab.snu.ac.kr/api/health` |
| Portal | `https://lab.snu.ac.kr` |

### 12.3 알림 채널

- 운영자 이메일 (Authentik과 동일)
- Slack (병행 운영 시)
- 다운 5분 이상 지속 시 알림

### 12.4 자원 모니터링

`netdata` 또는 `glances` 설치, 호스트에서 실행:

- CPU/RAM/디스크 사용량
- HDD 용량 임계치 알림 (80% 초과 시)

### 12.5 보안 로그 모니터링

매일 자동 요약 메일:

- fail2ban 차단 IP 수
- Authentik 로그인 실패 횟수
- Nginx 4xx/5xx 비율

`/opt/lab-stack/scripts/security-summary.sh` (cron 매일 09:00):

```bash
#!/bin/bash
{
  echo "=== fail2ban ==="
  sudo fail2ban-client status sshd
  echo ""
  echo "=== Authentik 실패 로그 (오늘) ==="
  docker logs authentik-server-1 --since 24h 2>&1 | grep -i "failed" | wc -l
} | mail -s "[Lab] 일일 보안 요약 $(date +%Y-%m-%d)" admin@lab.snu.ac.kr
```

### 12.6 체크포인트

- [ ] Uptime Kuma 모든 서비스 모니터 등록
- [ ] 의도적 다운 → 알림 메일 수신 확인
- [ ] 일일 보안 요약 메일 정상 수신

---

## 13. Phase 12: 멤버 온보딩

### 13.1 운영자 작업

1. Authentik에 정식 멤버 계정 생성 (이메일 초대)
2. 그룹 할당 (`lab-members`)
3. Huly 워크스페이스 초대
4. Overleaf 계정 발급 (방안 1 채택 시)

### 13.2 멤버 안내 문서 (Huly 위키에 게시)

다음 내용 포함:

#### 13.2.1 첫 로그인 가이드

- `https://auth.lab.snu.ac.kr` 접속
- 학교 메일로 받은 초대 링크 클릭
- 비밀번호 설정 + 2FA(TOTP) 등록 필수

#### 13.2.2 서비스별 사용법

- **Huly**: 위키, 채팅, 이슈 트래킹 사용법
- **Overleaf**: 별도 계정 발급 안내
- **MinIO/HF UI**: 모델/데이터셋 업로드 가이드 (boto3 예시)

#### 13.2.3 게스트 초대 가이드

- 정식 멤버가 게스트 초대하는 방법
- Authentik에서 invitation 토큰 발급
- 게스트에게 메일로 링크 전달
- 게스트 가입 시 운영자에게 자동 알림

#### 13.2.4 보안 정책

- 비밀번호 12자 이상
- 2FA 필수
- 외부 메일에 자동 포워딩 금지
- 모델 weight 등 민감 데이터는 private 버킷에만

### 13.3 Notion 데이터 마이그레이션

기존 Notion → Huly 이전:

1. Notion 워크스페이스 → Export → Markdown & CSV
2. ZIP 압축 풀기
3. Huly Import 기능 사용 (Markdown 파일 업로드)
4. 페이지 구조/링크 수동 검토

### 13.4 체크포인트

- [ ] 모든 정식 멤버 Authentik 등록 완료
- [ ] 안내 문서 Huly 위키에 게시
- [ ] 게스트 초대 흐름 1회 시연
- [ ] Notion 핵심 페이지 마이그레이션 완료

---

## 14. 일정 요약

| 주차 | 작업 | 산출물 |
|------|------|--------|
| Week 0 | 학교 신청 (도메인, 인증서, 방화벽), SMTP 정보 수령 | 발급 완료 |
| Week 1 | Phase 1 (인프라) + Phase 2 (SSL) + Phase 3 (Nginx 골격) | HTTPS 도달 가능 |
| Week 2 | Phase 4 (Authentik + 2FA + 초대 링크 + 알림) | SSO 동작 |
| Week 3 | Phase 5 (Huly + GitHub 연동 + Gantt 검증) | 메인 허브 가동 |
| Week 4 | Phase 6 (MinIO + 버킷 + OIDC) | 스토리지 가동 |
| Week 5~6 | Phase 7 MVP (HF-like UI: 로그인 + 리스트 + 상세 + 다운로드) | 모델 조회 가능 |
| Week 7 | Phase 7 v1 (업로드, 메타데이터, 권한) | 모델 업로드 가능 |
| Week 8 | Phase 8 (Overleaf) | 논문 협업 가능 |
| Week 9 | Phase 9 (포털) + Phase 10 (백업) + Phase 11 (모니터링) | 운영 자동화 |
| Week 10 | Phase 12 (멤버 온보딩, Notion 마이그레이션) | 정식 가동 |

---

## 15. 리스크 & 대응

| 리스크 | 영향 | 대응 |
|--------|------|------|
| Huly self-host에서 Gantt 미동작 | 핵심 기능 누락 | Plane 추가 배포로 보완 |
| Huly OIDC 미지원/불안정 | SSO 통합 어려움 | Nginx forward-auth 우회 또는 별도 계정 |
| Huly 모바일 앱 약함 | 학생 불편 | 초기엔 Slack 병행 |
| Overleaf SSO 어려움 | 추가 로그인 부담 | 방안 1(별도 계정) 채택 |
| 학교 인증서 만료 누락 | 서비스 중단 | 30일/15일/7일 자동 메일 |
| HDD 장애 | 모델/데이터셋 손실 | 백업 디스크 이중화 + 외부 cold storage |
| Authentik 장애 시 모든 서비스 로그인 불가 | 전체 마비 | 각 서비스에 emergency local admin 1개씩 유지 |
| 외부 공격 (브루트포스, DDoS) | 가용성 저하 | fail2ban + Authentik 2FA + Rate limit |
| 게스트 가입 악용 | 스팸/오용 | 초대 링크 방식 (자가 가입 차단) |
| 백업 자체가 손상/누락 | 복구 불가 | 월 1회 복구 테스트 |
| 사용자가 외부에 비밀 데이터 공유 | 정보 유출 | private 정책 기본화, 교육 |

---

## 16. 운영 체크리스트 (정식 가동 후)

### 16.1 일일

- [ ] 백업 cron 정상 실행 확인 (자동 알림 없으면 OK)
- [ ] 보안 요약 메일 검토

### 16.2 주간

- [ ] Uptime Kuma 다운타임 확인
- [ ] 디스크 용량 점검 (HDD, 백업 디스크)

### 16.3 월간

- [ ] 백업 복구 테스트
- [ ] 각 서비스 보안 업데이트
- [ ] 인증서 만료일 확인
- [ ] 사용자 활동 검토 (활성/비활성)

### 16.4 분기/연간

- [ ] 학교 인증서 갱신 (만료 30일 전)
- [ ] 메이저 버전 업그레이드 검토
- [ ] 사용자 권한 재검토

---

## 17. 즉시 시작할 것

다음 순서로 진행:

1. **학교 신청서 제출**
   - 도메인 + 와일드카드 인증서
   - 방화벽 80/443 인바운드
   - SMTP 사용 권한
2. **서버 준비**
   - Ubuntu 24.04 LTS 설치
   - HDD 마운트 (`/mnt/hdd/minio`)
   - 백업 디스크 마운트 (`/mnt/backup/lab`)
3. **Phase 1부터 순차 진행**

---

## 18. 참고 링크

- Authentik 공식 문서: https://goauthentik.io/docs/
- Huly self-host: https://github.com/hcengineering/huly-selfhost
- Overleaf toolkit: https://github.com/overleaf/toolkit
- MinIO 공식 문서: https://min.io/docs/minio/linux/index.html
- Nginx 보안 가이드: https://www.nginx.com/blog/

---

*문서 작성일: 2026-05-09*
*작성: Claude with Jaehee*
