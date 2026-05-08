# 09. Backup, Restore, and Observability

## 모듈 목표

운영 안정성은 v0.3 smoke test의 일부다. 모든 서비스가 뜨는 것만으로는 완료가 아니다. 최소 백업과 복구 가능성을 확인해야 한다.

포함:

- backup script skeleton
- service-specific backup inventory
- restore drill plan
- logs and health checks
- minimal monitoring
- update runbook

## v0.2 산출물

```text
deploy/scripts/90-backup-all.sh
deploy/scripts/91-backup-postgres.sh
deploy/scripts/92-backup-minio.sh
deploy/scripts/93-backup-gitea.sh
deploy/scripts/94-backup-nextcloud.sh
deploy/scripts/95-backup-overleaf.sh
deploy/scripts/96-check-all.sh
deploy/runbooks/backup-restore.md
deploy/runbooks/update-policy.md
deploy/runbooks/incident-response.md
```

## Backup inventory

| 서비스 | DB | Object/File | Config |
|---|---|---|---|
| Authentik | Postgres `authentik` | media/certs | blueprints, compose, env redacted |
| Plane | Postgres `plane` | MinIO `plane-uploads` | compose |
| Gitea | Postgres `gitea` | git volume, MinIO `gitea-lfs` | app.ini |
| MLflow | Postgres `mlflow` | MinIO `mlflow-artifacts` | compose |
| Nextcloud | Postgres `nextcloud` | data volume | config.php, apps |
| Overleaf | MongoDB `sharelatex` | project files | Dockerfile/config |
| MinIO | internal metadata | all buckets/policies | service policies |
| Nginx | none | cert/key | conf.d/snippets |

## Backup path

```text
/srv/lab-platform/backups/archive/
├── daily/YYYY-MM-DD/
├── weekly/YYYY-WW/
└── monthly/YYYY-MM/
```

Each backup directory contains:

```text
manifest.json
postgres/
minio/
files/
configs/
logs/
```

`manifest.json`에는 다음을 둔다.

- timestamp
- host
- git commit of deployment repo
- service image tags
- backup commands
- success/failure
- sha256 checksums

secret 값은 manifest에 기록하지 않는다.

## Postgres backup

DB별 dump:

```bash
pg_dump -U postgres -Fc authentik > authentik.dump
pg_dump -U postgres -Fc plane > plane.dump
pg_dump -U postgres -Fc gitea > gitea.dump
pg_dump -U postgres -Fc mlflow > mlflow.dump
pg_dump -U postgres -Fc nextcloud > nextcloud.dump
```

검증:

- dump file non-empty
- `pg_restore --list` 성공

## MinIO backup

후보:

```bash
mc mirror local/plane-uploads backups/...
mc mirror local/gitea-lfs backups/...
mc mirror local/mlflow-artifacts backups/...
```

주의:

- bucket policy와 service account도 기록해야 한다.
- 대용량 artifact bucket은 retention과 pruning 정책이 필요하다.

## Nextcloud backup

안전 절차:

1. maintenance mode on
2. DB dump
3. data/config/custom_apps backup
4. maintenance mode off

운영 불편을 줄이기 위해 새벽 시간대 cron으로 수행한다.

## Gitea backup

권장:

- `gitea dump`
- Postgres dump
- MinIO LFS bucket backup

`gitea dump`만으로 MinIO LFS가 모두 포함되는지 구현 단계에서 검증한다.

## Overleaf backup

대상:

- MongoDB dump
- project files
- custom Dockerfile/config

검증:

- sample project restore 가능성 문서화

## Restore drill

v0.3 전 최소 drill:

| 대상 | Drill |
|---|---|
| Postgres | 임시 DB에 `pg_restore` |
| MinIO | 임시 bucket에 object restore |
| Gitea | dump 생성과 archive list 확인 |
| Nextcloud | maintenance backup 절차 dry-run |
| Overleaf | Mongo dump 생성 확인 |

v0.4 이후:

- 별도 VM 또는 staging compose에서 full restore

## Minimal observability

v0.3 smoke에 필요한 최소:

- `docker compose ps`
- container logs tail
- Nginx access/error log
- disk usage
- Postgres readiness
- Redis ping
- MinIO bucket usage
- service HTTP check

Scripts:

```bash
deploy/scripts/96-check-all.sh
deploy/scripts/97-disk-usage.sh
deploy/scripts/98-service-logs.sh
```

## Health check endpoints

| 서비스 | Check |
|---|---|
| Authentik | `/if/flow/initial-setup/` or root |
| Gitea | root HTTP and API version |
| Plane | root HTTP, API logs |
| MLflow | root UI after auth, internal `/` |
| Nextcloud | `/status.php` |
| Collabora | `/hosting/discovery` |
| Overleaf | root HTTP |
| MinIO | internal health endpoint |

## Update policy

절차:

1. release notes 확인
2. backup
3. image tag 변경
4. `docker compose config`
5. `pull` 또는 `build`
6. `up -d`
7. logs 확인
8. smoke subset 실행
9. 운영 로그 기록

금지:

- `latest` 기반 무검증 업데이트
- 전체 서비스 동시 업데이트
- backup 없이 DB migration

## Incident response 초안

기본 순서:

1. 외부 노출 차단 필요 여부 판단
2. Nginx route disable 또는 firewall rule 적용
3. 관련 service logs 수집
4. auth logs 확인
5. secret 유출 가능성 판단
6. backup snapshot 보존
7. token/secret rotate
8. postmortem 기록

