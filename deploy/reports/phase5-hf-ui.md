# Phase 5 HF-like UI Report

Date: 2026-05-10
Host: current Docker host, runtime root `/opt/lab-stack`
Deployment commit: working tree
Result: conditional-pass (staging)

## Summary

- HF-like UI MVP serves a model/dataset catalog backed by Phase 4 MinIO.
- Metadata is tracked as a seed YAML catalog for MVP; object bytes remain in
  MinIO.
- Phase 5.2 adds Parquet preview coverage for `demo/sentiment-mini`.
- Phase 5.3 adds single-file direct upload with presigned PUT URLs, default
  overwrite protection, and HF UI origin CORS for model/dataset buckets.
- Full pass requires browser OIDC evidence after real DNS/TLS are ready.
- Staging validation completed with `STAGING_IP=127.0.0.1` and
  `PHASE5_REQUIRE_REAL_DOMAINS=false`.

## Automated Checks

Record command, timestamp, and result. Redact secret values.

```bash
bash -n deploy/scripts/43-bootstrap-hf-ui-storage.sh \
  deploy/scripts/44-check-hf-ui.sh \
  deploy/scripts/96-check-all.sh

docker compose -f deploy/compose/hf-ui/docker-compose.yml config
python3 -m py_compile deploy/hf-ui/app/main.py
node --check deploy/hf-ui/app/static/app.js
docker build -t lab/hf-ui:phase5.2-preview deploy/hf-ui/app
git diff --check
```

Result at 2026-05-10T17:50Z: passed.

Phase 5.2 local validation at 2026-05-10T18:52Z: passed.

- Python compile, JS syntax check, shell syntax check, compose config, Docker
  build, `git diff --check`, trailing-whitespace check, and in-image preview
  helper assertions passed.
- In-image assertions covered JSONL, CSV, JSON, Parquet rows/schema/stats,
  Parquet `schema[].source_type`, and Parquet byte-cap HTTP 413 behavior.
- Phase 5.2 preview staging coverage is included in the Phase 5.3
  `/opt/lab-stack` check pass below.

Phase 5.3 local static validation at 2026-05-10T19:13Z: passed.

- Python compile, JS syntax check, shell syntax check, env-loaded Compose
  config, Docker build, in-image upload presign API contract checks, and
  `git diff --check` passed.
- In-image assertions covered upload presign success, duplicate upload HTTP 409,
  invalid upload path HTTP 400, and existing download presign compatibility.

Phase 5.3 staging runtime validation at 2026-05-10T19:24Z: passed.

- Synced the HF UI app, compose file, check scripts, runbook, and report to
  `/opt/lab-stack`.
- Rebuilt `lab/hf-ui:phase5` and recreated the `hf-ui` container.
- `43-bootstrap-hf-ui-storage.sh` passed. The runtime returned `NotImplemented`
  for bucket-level CORS, so the script applied the planned global
  `api cors_allow_origin` fallback for `HF_UI_PUBLIC_URL`.
- `44-check-hf-ui.sh` passed with `STAGING_IP=127.0.0.1` and
  `PHASE5_REQUIRE_REAL_DOMAINS=false`; it verified preview checks, download,
  upload presign, CORS preflight, direct PUT, file-list refresh, uploaded JSONL
  preview readability, and duplicate upload HTTP 409.
- Integrated `96-check-all.sh` passed with `LABSTACK_INCLUDE_MINIO=true` and
  `LABSTACK_INCLUDE_HF_UI=true`.

Staging equivalents:

```bash
/opt/lab-stack/scripts/43-bootstrap-hf-ui-storage.sh
STAGING_IP=127.0.0.1 PHASE5_REQUIRE_REAL_DOMAINS=false \
  /opt/lab-stack/scripts/44-check-hf-ui.sh
STAGING_IP=127.0.0.1 \
  PHASE2_REQUIRE_REAL_DOMAINS=false \
  PHASE2_REQUIRE_SMTP=false \
  PHASE4_REQUIRE_REAL_DOMAINS=false \
  PHASE5_REQUIRE_REAL_DOMAINS=false \
  LABSTACK_INCLUDE_MINIO=true \
  LABSTACK_INCLUDE_HF_UI=true \
  /opt/lab-stack/scripts/96-check-all.sh
```

Results:

- Initial Phase 5 staging pass: `43-bootstrap-hf-ui-storage.sh` passed at
  2026-05-10T17:49Z, `44-check-hf-ui.sh` passed at 2026-05-10T17:50Z, and
  `96-check-all.sh` passed at 2026-05-10T17:51Z.
- Current Phase 5.3 staging pass: `43-bootstrap-hf-ui-storage.sh`,
  `44-check-hf-ui.sh`, and integrated `96-check-all.sh` all passed at
  2026-05-10T19:23-19:24Z after the upload implementation was deployed.
- Phase 5.2 Parquet staging coverage is included in the current Phase 5.3
  check pass.

## Runtime

- Container: `hf-ui` built from `lab/hf-ui:phase5` and running.
- Health: Docker health is `healthy`; `/api/health` returned `{"status":"ok"}`.
- Host ports: no host ports published by `hf-ui`.
- Nginx route: `https://hf.lab.example.ac.kr` returns HTTP 200 in staging via
  `--resolve hf.lab.example.ac.kr:443:127.0.0.1`.
- OIDC discovery:
  `https://auth.lab.example.ac.kr/application/o/hf-ui/.well-known/openid-configuration`
  returned HTTP 200 in staging.

## Catalog

- Model list: `/api/models` returned 1 item with staging bypass.
- Dataset list: `/api/datasets` returned 1 item with staging bypass.
- Detail: `/api/model/demo/tiny-transformer` returned `Tiny Transformer Demo`.
- README: model detail includes README render source from catalog/MinIO sample.
- File tree: `/api/model/demo/tiny-transformer/files` includes
  `model.safetensors`.
- Dataset files: `/api/dataset/demo/sentiment-mini/files` includes
  `train.jsonl`, `validation.csv`, `test.json`, and `sample.parquet`.
- Dataset preview: JSONL, CSV, JSON, and Parquet smoke checks are expected to
  return rows. Parquet preview also verifies schema/source type and numeric
  stats for `score` and `tokens`.

## Download And Upload

- Presigned URL domain: generated URLs use `https://s3.lab.example.ac.kr/...`.
- Model download: presigned download of `model.safetensors` succeeded.
- Dataset download: dataset listing is present; browser/manual dataset download
  remains part of full browser smoke.
- Upload v1: `POST /api/files/presign?action=upload` returns a presigned PUT URL
  for model/dataset files inside the catalog prefix.
- Overwrite policy: existing objects are rejected with HTTP 409 unless
  `overwrite=true` is provided.
- CORS: `43-bootstrap-hf-ui-storage.sh` configures `HF_UI_PUBLIC_URL` access for
  direct browser PUT to `lab-models` and `lab-datasets`; the check script
  validates OPTIONS preflight when reachable. On the current MinIO runtime,
  bucket CORS is unavailable and the global `api cors_allow_origin` fallback is
  used successfully.

## Browser OIDC

- Status: pending browser validation
- Callback: `https://hf.lab.example.ac.kr/oauth/callback`
- `lab-member` login: pending real browser OIDC evidence
- `lab-guest` behavior: pending real browser OIDC evidence

## Gate Decision

- Full-pass conditions met: no
- Conditional-pass reason: app/runtime/API/download/preview/upload smoke passed
  in local staging with fake lab domains resolved to localhost.
- Stop/fail reason: real DNS/TLS and browser OIDC login evidence are not yet
  available.
- Next action: when real domains are ready, disable staging bypass, run
  `/opt/lab-stack/scripts/44-check-hf-ui.sh` in strict mode, and capture browser
  OIDC plus upload evidence for `lab-member` and `lab-guest`.
