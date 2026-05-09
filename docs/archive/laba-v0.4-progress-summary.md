# v0.4 Strict-OSS Research Workspace 진행 요약

작성 시점: 2026-05-09

## 현재 방향

v0.3은 검증된 MLflow + Nextcloud/Collabora baseline으로 유지하고, v0.4.0은 strict-OSS 기준의 Notion-like 연구 워크스페이스 MVP로 확장하는 방향으로 구현했다.

v0.4 기본 활성 서비스 집합:

```text
core,edge,authentik,gitea,plane,mlflow,nextcloud,grist
```

핵심 책임 분리:

- Plane: 작업, 담당자, due date, 상태, project/module/cycle/view/activity의 canonical system
- Nextcloud Collectives: lab pages, meeting notes, SOP, onboarding, experiment notes, page/wiki/document hub의 canonical system
- Grist: people, teams, projects, resources, papers, datasets, experiments, GitHub refs, review queue, dashboard의 canonical structured DB layer
- Nextcloud Calendar: shared calendar와 recurring event의 canonical system

## 중요한 수정 판단

초기 계획에는 `gristlabs/grist-oss:v1.7.13`이 적혀 있었지만, 실제 Docker image tag는 leading `v` 없이 다음 값으로 검증했다.

```text
gristlabs/grist-oss:1.7.13
```

release label은 계속 `v1.7.13`로 문서화했다.

또한 Grist bootstrap API 인증은 `Authorization: Bearer`가 아니라 `X-Boot-Key` header를 써야 함을 임시 Grist container에서 확인했다.

## 구현된 것

### Grist 서비스

- `deploy/env/00-global.env.example`에 `GRIST_DOMAIN=data.lab.snu.ac.kr` 추가
- `deploy/env/65-grist.env.example` 추가
- `deploy/compose/grist/docker-compose.yml` 추가
- `deploy/nginx/conf.d/55-grist.conf` 추가
- `/srv/lab-platform/data/grist/persist` directory 생성/권한 처리 추가
- Postgres bootstrap에 `grist` DB/user 추가
- Authentik Grist OIDC bootstrap script 추가
- Authentik application skeleton에 `grist` 추가
- hosts/TLS SAN 생성 scripts에 `data.lab.snu.ac.kr` 추가

### v0.4 데이터 모델과 seed

- `deploy/data-model/lab-domain.v0.4.yaml` 추가
- Grist `Lab Research Hub` workspace/document seed script 추가
- Grist required tables:
  - `People`
  - `Teams`
  - `Projects`
  - `Pages`
  - `Tasks`
  - `Resources`
  - `Papers`
  - `Datasets`
  - `Experiments`
  - `GitHubRefs`
  - `Events`
  - `DashboardPages`
- `DashboardPages`에 `Dashboard`, `Card`, `Calendar` kind seed
- Plane demo seed가 v0.4 catalog에서 due date, labels, Collectives/Grist/GitHub reference link를 반영하도록 확장
- Nextcloud document hub seed가 `LAB_DOMAIN_CATALOG_VERSION=v0.4`를 지원하도록 확장

### Check와 backup

- `deploy/scripts/76-check-grist.sh` 추가
- `deploy/scripts/96-check-all.sh`에 `grist` service 추가
- `96-check-all.sh`가 enabled services를 보고 Authentik discovery slug를 자동 구성하도록 보강
- Postgres backup DB list에 `grist` 추가
- Grist persist backup script 추가
- `90-backup-all.sh`에서 Grist persist backup 호출

### 문서/기록

- Grist runbook 추가
- v0.4 research workspace planning doc 추가
- demo-data, nextcloud, backup, runtime gate, edge/Auth docs 업데이트
- validation report 추가
- history 기록 업데이트

## 검증 완료

정적 검증:

```bash
git diff --check
bash -n deploy/scripts/*.sh deploy/scripts/lib/*.sh
```

YAML/compose 검증:

```bash
python3 - <<'PY'
import yaml
for path in [
    'deploy/data-model/lab-domain.v0.3.yaml',
    'deploy/data-model/lab-domain.v0.4.yaml',
    'deploy/authentik/blueprints/30-applications.yaml',
    'deploy/compose/grist/docker-compose.yml',
]:
    yaml.safe_load(open(path, encoding='utf-8'))
PY

docker compose \
  --env-file deploy/env/00-global.env.example \
  --env-file deploy/env/10-core.env.example \
  --env-file deploy/env/65-grist.env.example \
  -f deploy/compose/grist/docker-compose.yml config
```

Runtime-adjacent smoke:

- disposable Grist container에서 `/status` HTTP 200 확인
- `X-Boot-Key` API access 확인
- `75-seed-grist-research-hub.sh`로 `Lab Research Hub` 생성 확인
- 같은 seed script 2회 실행으로 idempotency 확인
- `DashboardPages` record kind가 `Calendar,Card,Dashboard`로 존재함을 확인
- backup dry-run에서 `grist.dump`와 `grist-persist.tar.gz` command 포함 확인

## 아직 staging host에서 남은 확인

실제 `/srv/lab-platform/env/*.env` secrets와 staging host runtime이 필요해서 아직 남은 항목:

- Authentik Grist OIDC provider/application 실제 bootstrap
- `https://data.lab.snu.ac.kr` external Nginx/TLS route 확인
- Grist unauthenticated root redirect/deny 확인
- full `76-check-grist.sh`
- full integrated check:

```bash
ENABLED_SERVICES=core,edge,authentik,gitea,plane,mlflow,nextcloud,grist \
  /srv/lab-platform/scripts/96-check-all.sh
```

## 비교할 때 볼 만한 결정 지점

- Grist를 canonical structured DB로 둘지, Nextcloud Tables/Baserow류를 다시 검토할지
- Plane은 work/task canonical으로만 유지하고 GitHub integration은 URL reference로 충분한지
- Nextcloud Collectives를 page/wiki canonical으로 유지할지, 별도 wiki를 도입할지
- `GRIST_SANDBOX_FLAVOR=gvisor`를 기본값으로 둔 상태에서 host hardening 비용을 감수할지
- v0.4.1에서 browser smoke와 richer templates를 먼저 할지, v0.5 integration wave로 바로 넘어갈지

