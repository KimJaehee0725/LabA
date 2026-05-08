# 08. Overleaf CE Module

## 모듈 목표

Overleaf CE는 논문 LaTeX 공동 편집을 제공한다.

포함:

- Overleaf CE 배포 방식 결정
- MongoDB/Redis 구성
- admin/user 생성 절차
- SMTP
- TeX Live 패키지 전략
- Gitea 백업 workflow

제외:

- 공식 SSO
- Track Changes
- Real-time comments
- Rich project history

## 공식 문서 반영사항

Overleaf 공식 on-premises 문서는 Community Edition과 Server Pro 배포에 Toolkit을 권장한다. Toolkit은 Docker Compose wrapper와 설정 파일을 제공하고, 단일 서버/VM 환경을 대상으로 한다.

v0.1 결정:

- v0.2에서는 Overleaf Toolkit 사용 여부를 우선 검토한다.
- 직접 compose를 만들더라도 Toolkit 구조와 설정 파일을 참고한다.
- CE의 SSO 제약은 명확히 문서화한다.

## v0.2 산출물

```text
deploy/compose/overleaf/docker-compose.yml
deploy/compose/overleaf/Dockerfile
deploy/nginx/conf.d/70-overleaf.conf
deploy/scripts/80-check-overleaf.sh
deploy/runbooks/overleaf.md
```

Toolkit 채택 시:

```text
deploy/overleaf-toolkit-notes.md
```

## 의존성

- MongoDB
- Redis
- Nginx: `papers.lab.snu.ac.kr`
- SMTP
- Optional Gitea remote for final paper backup

## 배포 방식 선택

| 방식 | 장점 | 단점 | v0.1 판단 |
|---|---|---|---|
| Overleaf Toolkit | 공식 권장, 운영 helper 존재 | 기존 공통 compose 구조와 다름 | 우선 검토 |
| 직접 compose | 전체 플랫폼과 일관성 높음 | 공식 운영 helper를 놓칠 수 있음 | Toolkit 검토 후 |

v0.2에서 먼저 Toolkit doctor/config 구조를 확인하고, 전체 platform compose와 충돌하지 않는지 판단한다.

## 데이터 경로

```text
/srv/lab-platform/data/overleaf/
├── overleaf/
├── mongo/
└── redis/
```

Mongo replica set 초기화가 필요할 수 있다.

## 계정 정책

v0.2/v0.3:

- admin 생성
- admin이 사용자 초대
- Authentik SSO 없음

절차:

```bash
docker exec overleaf grunt user:create-admin --email=admin@example.edu
```

출력 activation URL은 HTTPS domain으로 변경해 사용한다.

보안:

- activation URL은 secret으로 취급한다.
- admin 계정 password는 강하게 설정한다.
- 사용자 수가 늘면 Authentik LDAP outpost를 후속 검토한다.

## TeX Live 전략

후보:

| 방식 | 장점 | 단점 |
|---|---|---|
| 컨테이너 내부 수동 `tlmgr` | 빠름 | 컨테이너 재생성 시 소실 위험 |
| persistent volume | 설치 유지 | image 재현성 낮음 |
| custom image | 재현성 높음 | build 시간 증가 |

v0.2 기본:

- custom Dockerfile 후보를 만든다.
- 최소 한국어/논문 패키지를 포함한다.

초기 패키지:

```text
kotex-utf
kotex-utils
kotex-plain
hcr-lvt
unfonts-core
latexmk
biber
biblatex
chemfig
pgfplots
tikz-cd
```

`scheme-full`은 이미지 크기와 build 시간을 보고 후속 결정한다.

## SMTP

필수:

- 사용자 초대
- password reset

검증:

- invite email
- forgot password email
- logs에서 SMTP error 없음

## Gitea 백업 workflow

운영 규칙:

- 최종 논문 산출물은 Gitea `lab-papers` org에 push한다.
- Overleaf project Git URL을 clone하고 Gitea remote를 추가한다.

Smoke:

```bash
git clone https://papers.lab.snu.ac.kr/git/<project-id>
git remote add lab-hub git@hub.lab.snu.ac.kr:2222/lab-papers/test-paper.git
git push lab-hub main
```

## 백업

대상:

- MongoDB `sharelatex`
- Overleaf project files
- custom image Dockerfile
- config

검증:

- `mongodump`
- project file tar
- sample restore note

## v0.3 Smoke

- admin activation
- user invite
- sample LaTeX compile
- Korean LaTeX compile
- project clone via Git
- Gitea remote push

## 위험

| 위험 | 대응 |
|---|---|
| CE 기능 제약 오해 | README에 CE 미포함 기능 명시 |
| SSO 미지원 | v0에서는 수동 계정으로 명시 |
| TeX package 소실 | custom image 또는 persistent strategy |
| Mongo replica 오류 | runbook에 `rs.status`와 init 절차 |
| WebSocket 협업 실패 | Nginx socket route smoke 포함 |

