# 05. Overleaf (ShareLaTeX CE)

논문 LaTeX 공동 편집.

## 공식 자료

- 문서: https://github.com/overleaf/overleaf/wiki
- Toolkit: https://github.com/overleaf/toolkit (선택)

## CE 제약사항

Overleaf Community Edition은 **다음 기능 미포함**:
- Track Changes (변경 이력)
- Real-time Comments
- Rich Project History
- Symbol Palette
- Reference Manager 통합

대안:
- 변경 이력 → Git 통합 (`git push`로 외부 저장)
- 코멘트 → Plane Pages에서 별도 논의

## 디렉토리

```
/srv/lab-platform/overleaf/
├── docker-compose.yml
├── mongo-init.js
├── data/
│   ├── overleaf/      # 사용자 프로젝트, TeX Live
│   ├── mongo/
│   └── redis/
```

## 첫 admin 생성

서비스 시작 후:

```bash
# 관리자 등록 URL 생성
docker exec overleaf grunt user:create-admin --email=admin@snu.ac.kr

# 출력 예:
# Public registration URL: http://lab.snu.ac.kr:80/user/activate?token=abc123...

# 위 URL을 https로 변경하고 브라우저로 접속해 비밀번호 설정
# 실제 URL: https://papers.lab.snu.ac.kr/user/activate?token=abc123...
```

## 일반 사용자 생성

방법 1 (가장 쉬움): admin이 사용자 초대
- Admin 로그인 > Manage Users > Invite User > 이메일 입력
- 사용자에게 활성화 이메일 발송

방법 2 (CLI):
```bash
docker exec overleaf grunt user:create --email=member@snu.ac.kr
# 비밀번호 설정 URL 출력
```

## Overleaf SSO

Overleaf CE는 **공식 SSO 미지원**. 대안:

### 옵션 A: 사용자 수동 등록 (간단)

위 admin 초대 방식. SSO 없이 별도 비밀번호 관리.

### 옵션 B: SAML 패치 (커뮤니티)

Overleaf Pro 코드의 SAML 모듈을 CE에 적용한 fork 존재. 비공식이라 권장 X.

### 옵션 C: 외부 인증 plugin (ldap-auth)

```yaml
environment:
  EXTERNAL_AUTH: ldap
  OVERLEAF_LDAP_URL: ldaps://auth.lab.snu.ac.kr:636
  OVERLEAF_LDAP_BIND_DN: cn=overleaf,ou=service,dc=...
  OVERLEAF_LDAP_BIND_CREDENTIALS: ...
  OVERLEAF_LDAP_SEARCH_BASE: ou=users,dc=...
  OVERLEAF_LDAP_SEARCH_FILTER: (uid={{username}})
```

Authentik의 LDAP outpost를 통해 가능. 단 설정 복잡.

**현실적 선택**: 옵션 A로 시작 → 사용자가 늘어나면 옵션 C 검토.

## TeX Live 패키지 설치

기본 이미지의 TeX Live는 minimal scheme. 한국어 LaTeX 등 추가 필요:

```bash
# 컨테이너 진입
docker exec -it overleaf bash

# 인덱스 업데이트
tlmgr update --self
tlmgr update --all

# 한국어 패키지
tlmgr install kotex-utf kotex-utils kotex-plain hcr-lvt unfonts-core

# 자주 쓰는 패키지
tlmgr install latexmk biber biblatex chemfig pgfplots tikz-cd

# 또는 전체 설치 (5GB, 30분)
tlmgr install scheme-full

exit

# 설치 후 컨테이너 재시작 불필요 (즉시 반영)
```

설치된 패키지는 컨테이너 내부에 저장됨. 컨테이너 삭제 시 사라지므로 **persistent 볼륨에 마운트** 또는 **커스텀 이미지 빌드** 권장:

```dockerfile
# /srv/lab-platform/overleaf/Dockerfile (선택)
FROM sharelatex/sharelatex:latest

RUN tlmgr update --self && \
    tlmgr install kotex-utf kotex-utils kotex-plain hcr-lvt unfonts-core \
                   latexmk biber biblatex chemfig pgfplots tikz-cd
```

## SMTP 설정

`.env`의 SMTP 설정이 정확하면 자동 작동. 테스트:

```bash
# 사용자 비밀번호 재설정 메일 발송 테스트
# UI에서: Login > Forgot Password > 이메일 입력
```

문제 발생 시:
```bash
docker logs overleaf | grep -i smtp
docker logs overleaf | grep -i mail
```

## Git 통합

Overleaf 프로젝트를 Gitea에 백업/동기화:

```bash
# Overleaf 프로젝트의 Git URL 확인 (Settings > Sync > Git)
git clone https://papers.lab.snu.ac.kr/git/<project-id>

# 별도 remote 추가
cd <project-id>
git remote add lab-hub git@hub.lab.snu.ac.kr:2222/lab-papers/neurips-2026.git
git push lab-hub main
```

논문 최종본은 항상 Gitea에 push해 보존.

## 백업 항목

| 데이터 | 위치 | 중요도 |
|---|---|---|
| 사용자/프로젝트 메타데이터 | MongoDB `sharelatex` DB | 매우 높음 |
| 프로젝트 파일 (.tex, 그림 등) | `/srv/lab-platform/overleaf/data/overleaf/` | 매우 높음 |
| Redis 세션 | (휘발성, 백업 불필요) | 낮음 |
| TeX Live 설치본 | `/srv/lab-platform/overleaf/data/overleaf/` | 중간 (재설치 가능) |

```bash
# MongoDB 덤프
docker exec overleaf-mongo mongodump --archive=/tmp/overleaf.archive
docker cp overleaf-mongo:/tmp/overleaf.archive backup-loc/

# 사용자 데이터
tar -czf overleaf-data.tar.gz -C /srv/lab-platform/overleaf/data overleaf
```

## 트러블슈팅

**프로젝트 컴파일 시 timeout**:
- 기본 60초 → 늘리기:
  ```yaml
  COMPILE_TIMEOUT: "180"  # 초
  ```

**한국어 깨짐**:
- 패키지 설치: `tlmgr install kotex-utf`
- 문서 첫 줄에: `\usepackage{kotex}`
- XeLaTeX 또는 LuaLaTeX 사용 (한국어 잘 처리)

**Mongo replica set 에러**:
```bash
docker exec overleaf-mongo mongosh --eval 'rs.status()'
# 필요 시 재초기화
docker exec overleaf-mongo mongosh --eval 'rs.initiate({_id:"overleaf",members:[{_id:0,host:"overleaf-mongo:27017"}]})'
```

**WebSocket 연결 실패 (실시간 협업 안 됨)**:
- Nginx `socket.io` 라우팅 확인 (Day 4 문서)
- Cloudflare 사용 시 WebSocket 활성화 확인 (대시보드 > Network)

## 업데이트

```bash
cd /srv/lab-platform/overleaf
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d

# 마이그레이션 자동
docker logs -f overleaf
```

Overleaf는 업데이트 시 마이그레이션 시간이 길 수 있음 (~10분). 첫 부팅 보고 후 사용.
