# 02. Edge Nginx and TLS Module

## 모듈 목표

Edge module은 외부 트래픽을 받는 유일한 진입점을 만든다.

포함:

- Nginx compose
- TLS 파일 위치
- 공통 proxy snippets
- 서비스별 server block skeleton
- 방화벽 기준
- upload/WebSocket/Forward Auth 라우팅 원칙

## v0.2 산출물

```text
deploy/compose/edge/docker-compose.yml
deploy/nginx/nginx.conf
deploy/nginx/conf.d/00-http-redirect.conf
deploy/nginx/conf.d/10-authentik.conf
deploy/nginx/conf.d/20-plane.conf
deploy/nginx/conf.d/30-gitea.conf
deploy/nginx/conf.d/40-mlflow.conf
deploy/nginx/conf.d/50-nextcloud.conf
deploy/nginx/conf.d/60-collabora.conf
deploy/nginx/conf.d/70-overleaf.conf
deploy/nginx/conf.d/80-minio-console.conf
deploy/nginx/snippets/proxy-params.conf
deploy/nginx/snippets/security-headers.conf
deploy/nginx/snippets/ssl-params.conf
deploy/nginx/snippets/websocket.conf
deploy/nginx/snippets/upload-large.conf
deploy/scripts/10-check-edge.sh
deploy/runbooks/edge-nginx.md
```

## 포트 정책

Nginx만 host port를 publish한다.

| Port | 용도 |
|---:|---|
| 80 | HTTP redirect, ACME HTTP-01 후보 |
| 443 | HTTPS |

Gitea SSH는 Gitea 모듈에서 `2222`로 별도 다룬다.

금지:

- 앱 내부 HTTP port publish
- Postgres/Redis/MinIO API publish
- Authentik internal direct publish
- Collabora direct `9980` publish

## TLS 계획

도메인 확정 전 v0.2에서는 경로와 구조만 고정한다.

```text
/srv/lab-platform/nginx/ssl/origin.crt
/srv/lab-platform/nginx/ssl/origin.key
```

TLS 방식 후보:

| 방식 | v0.2 판단 |
|---|---|
| Let's Encrypt HTTP-01 | 도메인과 80 공개 가능 여부 확인 후 |
| Let's Encrypt DNS-01 | DNS API 접근 가능하면 선호 |
| 기관 인증서 | 학교 정책 확인 필요 |
| Cloudflare Origin cert | Cloudflare 사용 전제일 때만 |
| self-signed | 내부 smoke test 한정 |

v0.3 smoke test에서는 실제 도메인이 없으면 `/etc/hosts`와 self-signed cert로 내부 검증을 허용한다.

## 공통 proxy header

`proxy-params.conf` 후보:

```nginx
proxy_http_version 1.1;
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Port $server_port;
proxy_redirect off;
```

서비스별로 추가 header가 필요한 경우 server block에서만 확장한다.

## Security headers

기본 후보:

```nginx
add_header X-Content-Type-Options nosniff always;
add_header X-Frame-Options SAMEORIGIN always;
add_header Referrer-Policy strict-origin-when-cross-origin always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

주의:

- CSP는 서비스별 호환성 문제가 생기기 쉬워 v0.2에서는 강제하지 않는다.
- HSTS는 실제 HTTPS와 도메인이 안정화된 뒤 켠다.
- Overleaf, Nextcloud, Collabora는 iframe/WebSocket 정책과 충돌 가능성이 있다.

## 서비스별 routing 계획

| Domain | Upstream | 특수 설정 |
|---|---|---|
| `auth.lab.snu.ac.kr` | `authentik-server:9000` | WebSocket 가능성 확인 |
| `lab.snu.ac.kr` | Plane web/API | Plane 공식 route 확인 |
| `hub.lab.snu.ac.kr` | `gitea:3000` | large push/LFS, SSH 별도 |
| `mlflow.lab.snu.ac.kr` | `mlflow:5000` | Authentik Forward Auth |
| `files.lab.snu.ac.kr` | `nextcloud:80` | large upload, WebDAV |
| `office.lab.snu.ac.kr` | `collabora:9980` | WebSocket, WOPI |
| `papers.lab.snu.ac.kr` | `overleaf:80` | WebSocket/socket.io |
| `storage.lab.snu.ac.kr` | `minio:9001` | Console only |

## Upload limits

| 서비스 | 초기 `client_max_body_size` |
|---|---:|
| Gitea | `50G` |
| MLflow | `50G` |
| Nextcloud | `10G` 또는 정책 결정 |
| Overleaf | `512M` |
| Plane | `1G` |
| Authentik | `100M` |

대용량 서비스는 다음을 검토한다.

```nginx
proxy_request_buffering off;
proxy_buffering off;
```

Gitea와 Nextcloud는 무조건 끄기보다 실제 동작과 메모리/디스크 영향을 보고 결정한다.

## WebSocket

WebSocket snippet:

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection $connection_upgrade;
```

`map`은 nginx main config에 둔다.

적용 후보:

- Authentik
- Overleaf
- Collabora
- Plane

## MLflow Forward Auth 라우팅

MLflow는 Authentik Proxy Outpost를 통한다.

기본 구조:

```nginx
location /outpost.goauthentik.io {
    proxy_pass http://authentik-outpost-mlflow:9000/outpost.goauthentik.io;
}

location / {
    auth_request /outpost.goauthentik.io/auth/nginx;
    error_page 401 = @goauthentik_proxy_signin;
    proxy_pass http://mlflow:5000;
}
```

주의:

- outpost container는 `lab_backend`에 붙인다.
- outpost token은 `/srv/lab-platform/env/50-mlflow.env`.
- Docker socket 자동 outpost 관리는 v0.2 기본안이 아니다.

## 방화벽 계획

UFW 후보:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 2222/tcp  # Gitea SSH 필요 시
ufw enable
```

실제 SSH 포트와 학교 서버 정책을 먼저 확인한다.

## 검증 기준

Edge 완료 조건:

- `nginx -t` 성공
- HTTP가 HTTPS로 redirect
- 각 domain server block이 올바른 upstream으로 연결
- 의도치 않은 host port 없음
- large upload 설정이 서비스별로 명시됨
- Forward Auth path가 MLflow에서만 적용됨

## v0.3 Smoke

- `curl -k https://auth.../` 응답
- `curl -k https://hub.../` 응답
- `curl -k https://files.../status.php` 응답
- `curl -k https://office.../hosting/discovery` 응답
- 인증 전 MLflow가 Authentik login으로 redirect
