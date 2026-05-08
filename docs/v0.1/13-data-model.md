# 13. v0.3 Lab Domain Data Model

작성일: 2026-05-08

이 문서는 v0.3 smoke/demo 기준의 Lab Platform 운영 도메인 모델을 고정한다. 별도 Lab Platform 메타데이터 DB를 만들지 않고, 각 애플리케이션이 이미 소유한 데이터를 하나의 논리 모델로 정리한다.

카탈로그 파일은 `deploy/data-model/lab-domain.v0.3.yaml`이다. 운영 서버에서는 같은 파일을 `/srv/lab-platform/data-model/lab-domain.v0.3.yaml`에 배치해 `52-seed-demo-data.sh`의 기준 데이터로 쓴다. 실제 password, token, client secret은 계속 `/srv/lab-platform/env/*.env`에만 둔다.

## System of Record

| 엔티티 | System of record | v0.3 상태 | 비고 |
|---|---|---|---|
| `LabUser` | Authentik | seed | `demo.member` 계정. Plane에는 현재 local login 사용자로 동기 seed |
| `LabGroup` | Authentik | seed | `lab-member` |
| `Project` | Plane | seed | `lab-demo` workspace 안의 Plane projects |
| `CodeRepository` | Gitea | seed | 공개 demo repositories |
| `Experiment` | MLflow | planned | 앱 wave 연결 전까지 논리 모델만 유지 |
| `Artifact` | MLflow/MinIO | planned | MLflow artifact store 연결 후 seed |
| `DocumentWorkspace` | Nextcloud | planned | group folders wave에서 seed |
| `PaperProject` | Overleaf | planned | Overleaf wave에서 seed |
| `AccessGrant` | Authentik, Plane, Gitea | seed/planned | 서비스별 membership/visibility로 표현 |

Plane/Auth OIDC는 아직 닫히지 않았다. v0.3 현재 상태는 Plane local login이며, Authentik generic OIDC 연결은 v0.3 blocker로 추적한다.

## Entity Definitions

### LabUser

연구실 사용자의 identity 기준 엔티티다. Authentik `User`가 원본이며, Gitea/Plane/Nextcloud/Overleaf의 사용자는 OIDC 또는 앱별 bootstrap 과정에서 파생된다.

v0.3 seed:

| 필드 | 값 |
|---|---|
| `id` | `demo-member` |
| `username` | `demo.member` |
| `email` | `demo.member@example.invalid` |
| `display_name` | `Demo Member` |
| `groups` | `lab-member` |

Password는 카탈로그에 쓰지 않는다. staging 값은 `/srv/lab-platform/env/99-demo.env`의 `DEMO_PASSWORD`만 사용한다.

### LabGroup

권한 부여의 기본 단위다. v0.3에서는 Authentik group을 기준으로 한다.

| 그룹 | System of record | 용도 |
|---|---|---|
| `lab-member` | Authentik | 일반 연구실 사용자 기본 접근 |

### Project

연구실 업무 단위다. v0.3에서는 Plane project로 표현한다. `lab-demo` workspace 안에 다음 두 project를 seed한다.

| Project | Identifier | Issues |
|---|---|---|
| `Platform Rollout` | `ROLL` | 3 |
| `Research Workbench` | `RND` | 3 |

상태 집합은 `Backlog`, `Ready`, `In Progress`, `Done`이다.

### CodeRepository

코드와 템플릿 자료의 기준 엔티티다. Gitea repository가 원본이다.

| Repository | Visibility | 용도 |
|---|---|---|
| `lab-platform-demo` | public | 플랫폼 demo walkthrough |
| `vision-baseline-demo` | public | baseline code/metrics placeholder |
| `paper-template-demo` | public | Overleaf wave용 paper template placeholder |

Gitea owner는 운영 env의 `DEMO_GITEA_OWNER`로 결정하며, 현재 cleanup 기본값과 맞추기 위해 `gitea-bootstrap-admin`을 기본으로 둔다.

### Experiment

MLflow experiment가 원본이다. v0.3에서는 `demo-baseline-001`을 planned 상태로만 둔다. `vision-baseline-demo` repository와 `Research Workbench` project를 연결하는 논리 관계를 먼저 고정하고, MLflow app wave에서 실제 seed/check를 붙인다.

### Artifact

MLflow artifact와 그 backing MinIO object가 원본이다. v0.3 planned 항목은 `demo-baseline-metrics`이며, synthetic metrics JSON을 가리킨다.

### DocumentWorkspace

Nextcloud group folder 또는 shared folder가 원본이다. v0.3 planned 항목은 `lab-demo-documents`이고 `lab-member` group 소유로 모델링한다.

### PaperProject

Overleaf project가 원본이다. v0.3 planned 항목은 `lab-platform-demo-paper`이고 `paper-template-demo` repository의 `main.tex`를 source template로 참조한다.

### AccessGrant

접근 권한은 중앙 테이블로 새로 저장하지 않는다. 각 앱의 권한 모델을 논리적으로 묶어서 표시한다.

| Grant | System of record | 의미 |
|---|---|---|
| `demo-member-lab-member` | Authentik | demo user가 `lab-member` group에 속함 |
| `demo-member-plane-workspace` | Plane | Plane local user가 `lab-demo` workspace member |
| `public-demo-repositories` | Gitea | demo repositories가 public read 가능 |

## Relationships

```text
LabUser(demo-member)
  -> LabGroup(lab-member)
  -> Plane Workspace(lab-demo)
      -> Project(platform-rollout)
      -> Project(research-workbench)
          -> Experiment(demo-baseline-001, planned)
              -> Artifact(demo-baseline-metrics, planned)
  -> CodeRepository(vision-baseline-demo)
  -> CodeRepository(paper-template-demo)
      -> PaperProject(lab-platform-demo-paper, planned)
  -> DocumentWorkspace(lab-demo-documents, planned)
```

## Catalog Contract

`deploy/data-model/lab-domain.v0.3.yaml`은 비밀값 없는 desired state다.

- `phase: seed`: v0.3 demo seed script가 실제 생성/갱신하는 항목
- `phase: planned`: 앱 wave 전이므로 관계와 이름만 고정한 항목
- `system_of_record`: 실제 원본 데이터를 소유하는 서비스
- `*_ref`: 같은 catalog 안의 논리 ID 참조
- `*_env`: 운영 환경별 값이 필요한 경우 참조할 env var 이름

`52-seed-demo-data.sh`는 현재 `phase: seed`인 Authentik, Gitea, Plane 항목만 처리한다. MLflow, Nextcloud, Overleaf planned 항목은 후속 app wave에서 별도 seed/check로 연결한다.
