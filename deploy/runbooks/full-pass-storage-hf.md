# Storage And HF UI Full-Pass Readiness

Status: storage/HF UI staging conditional-pass, full-pass pending.

This runbook closes the remaining Phase 4 MinIO and Phase 5 HF UI readiness
gap after real DNS and trusted TLS are available. The staging reports already
show that shared MinIO, public/private S3 behavior, backup smoke, HF catalog,
preview, download, direct upload, duplicate-upload rejection, and integrated
checks pass with localhost domain resolution. Full pass requires strict-mode
automation plus browser OIDC and role evidence on the real domains.

## Scope

- MinIO Console: `https://files.lab.example.ac.kr`
- Public S3 API: `https://s3.lab.example.ac.kr`
- HF UI: `https://hf.lab.example.ac.kr`
- Authentik: `https://auth.lab.example.ac.kr`
- Runtime root: `/opt/lab-stack`
- Phase 4 report: `/opt/lab-stack/reports/phase4-minio-storage.md`
- Phase 5 report: `/opt/lab-stack/reports/phase5-hf-ui.md`

Do not record secrets, OIDC client secrets, root credentials, S3 access keys,
presigned URL query strings, session cookies, or bearer tokens in screenshots,
reports, terminals, or issue comments.

## Role Matrix

| Role | MinIO Console | HF UI |
| --- | --- | --- |
| `lab-admin` | Expected to sign in through Authentik and receive the MinIO `policy` claim value `consoleAdmin`; Console administration is allowed. | Expected to sign in and use model/dataset list, detail, preview, download, and upload flows because `lab-admin` is in `HF_UI_REQUIRE_GROUPS`. |
| `lab-member` | Expected to sign in through Authentik and receive `lab-storage-member-rw`; working storage buckets are visible according to that policy, Console admin actions are not expected. | Expected to sign in and use model/dataset list, detail, preview, download, and upload flows. This is the primary browser smoke role. |
| `lab-collab` | Expected to sign in through Authentik and receive `lab-storage-member-rw`; behavior should match `lab-member`. | Expected to sign in and use model/dataset list, detail, preview, download, and upload flows. |
| `lab-guest` | Expected to be blocked by the active MinIO application policy before useful Console access; if a token is issued unexpectedly, it must not grant a useful MinIO policy. | Expected to be denied by HF UI authorization because default required groups are `lab-admin,lab-member,lab-collab`; record HTTP 403 or visible access-denied behavior. |

## Strict-Mode Command Sequence

Run this only after real DNS resolves to the deployment and TLS chains validate
without the staging certificate workaround. Do not set `STAGING_IP`,
`CURL_RESOLVE`, `PHASE4_REQUIRE_REAL_DOMAINS=false`, or
`PHASE5_REQUIRE_REAL_DOMAINS=false`.

```bash
sudo /opt/lab-stack/scripts/33-bootstrap-minio-storage.sh
sudo /opt/lab-stack/scripts/34-check-minio-storage.sh
sudo /opt/lab-stack/scripts/35-check-minio-backup-smoke.sh

sudo /opt/lab-stack/scripts/43-bootstrap-hf-ui-storage.sh
sudo /opt/lab-stack/scripts/44-check-hf-ui.sh

sudo LABSTACK_INCLUDE_MINIO=true \
  LABSTACK_INCLUDE_HF_UI=true \
  /opt/lab-stack/scripts/96-check-all.sh
```

Expected strict-mode result:

- `FILES_DOMAIN`, `S3_DOMAIN`, `AUTH_DOMAIN`, and `HF_DOMAIN` are real
  non-example values.
- `minio` and `hf-ui` are running, healthy, and publish no host ports.
- MinIO buckets exist, versioning is enabled, private anonymous download is
  denied, and `lab-public` anonymous download succeeds.
- Backup smoke mirrors an object from `lab-backups`.
- HF UI health, index, Authentik discovery, catalog, detail, preview, download,
  upload presign, CORS preflight, direct PUT, file-list refresh, uploaded JSONL
  preview, and duplicate upload HTTP 409 checks pass.

If `HF_UI_ALLOW_STAGING_BYPASS=true` is still present in production, stop and
remove it before full-pass signoff. The automated HF catalog checks require
browser OIDC once the staging bypass is disabled, so browser evidence below is
part of the full-pass gate.

## MinIO Console Browser Evidence

Use a private browser session for each role. Capture screenshots or notes with
timestamp, role, target URL, and result. Redact usernames if required by local
policy, and never capture cookies or token details.

1. Open `https://files.lab.example.ac.kr`.
2. Confirm the Console offers Authentik/OIDC sign-in.
3. Sign in as `lab-admin`.
4. Record that the OIDC `policy` claim maps to `consoleAdmin` by confirming
   admin Console access is available.
5. Sign out and sign in as `lab-member`.
6. Record that the OIDC `policy` claim maps to `lab-storage-member-rw` by
   confirming working storage bucket access without Console admin access.
7. Repeat the member check with `lab-collab` if that role is in the release
   acceptance sample.
8. Attempt launch or sign-in as `lab-guest` and record that Console access is
   blocked by the application policy or does not receive a useful MinIO policy.
9. In a clean unauthenticated browser context, open a known object under
   `https://s3.lab.example.ac.kr/lab-public/...` and confirm it downloads.
10. In the same unauthenticated context, open a known object under a private
    bucket such as `lab-artifacts` and confirm HTTP 401 or 403.

Evidence to paste into the report:

```text
MinIO Console browser evidence:
- lab-admin: OIDC login succeeded; policy claim behavior confirmed as consoleAdmin; timestamp:
- lab-member: OIDC login succeeded; policy claim behavior confirmed as lab-storage-member-rw; timestamp:
- lab-collab: OIDC login result; policy claim behavior; timestamp:
- lab-guest: blocked/denied result; timestamp:
- lab-public anonymous download: pass/fail, object path, timestamp:
- private bucket anonymous download: HTTP 401/403 expected, object path, timestamp:
```

## HF UI Browser Evidence

Use `lab-member` as the primary smoke role, then verify denial for `lab-guest`.
Use a fresh browser profile or private window when switching roles.

1. Open `https://hf.lab.example.ac.kr`.
2. Confirm sign-in redirects to Authentik and returns to
   `https://hf.lab.example.ac.kr/oauth/callback`.
3. Sign in as `lab-member`.
4. Confirm the model list and dataset list load.
5. Open model `demo/tiny-transformer`; confirm detail metadata, README, and
   file list render.
6. Download `model.safetensors` from the model file list and confirm the
   browser receives a file from the public S3 domain.
7. Open dataset `demo/sentiment-mini`; confirm detail metadata, README, and file
   list render.
8. Select previews for `train.jsonl`, `validation.csv`, `test.json`, and
   `sample.parquet`; confirm rows, schema, and stats render without layout
   overlap.
9. Upload a small supported JSONL file to a new smoke path, for example
   `smoke/browser-YYYYMMDDTHHMMSSZ.jsonl`.
10. Confirm upload progress reaches success, the file list refreshes, and the
    uploaded JSONL preview is readable.
11. Upload the same file to the same path with overwrite disabled and confirm
    the UI blocks replacement with the existing-file message. The backing API
    should return HTTP 409.
12. Enable overwrite for the same path and confirm replacement succeeds.
13. Download `train.jsonl` from the dataset file list.
14. Upload or select an unsupported preview extension such as `.txt` or `.bin`.
    Confirm it remains downloadable but is not offered as a preview file; if the
    preview API is called directly for that path, HTTP 400
    `unsupported preview file type` is expected.
15. Sign out, then sign in or attempt access as `lab-guest`; record the 403 or
    access-denied behavior.

Evidence to paste into the report:

```text
HF UI browser evidence:
- lab-member OIDC login and callback: pass/fail, timestamp:
- model list/detail and model download: pass/fail, timestamp:
- dataset list/detail and JSONL/CSV/JSON/Parquet previews: pass/fail, timestamp:
- upload path:
- upload success and file-list refresh: pass/fail, timestamp:
- duplicate upload without overwrite: HTTP 409/UI existing-file block confirmed, timestamp:
- overwrite upload: pass/fail, timestamp:
- dataset download: pass/fail, timestamp:
- unsupported file behavior: downloadable but no preview, or preview API HTTP 400, timestamp:
- lab-guest authorization result: pass/fail, timestamp:
```

## CORS Note

`43-bootstrap-hf-ui-storage.sh` first attempts bucket-level CORS for
`lab-models` and `lab-datasets`. On the current MinIO runtime, bucket CORS may
return `NotImplemented`; that is acceptable only when the script applies the
global `api cors_allow_origin` fallback for `HF_UI_PUBLIC_URL` and
`44-check-hf-ui.sh` confirms the browser PUT preflight allows `PUT`.

For full pass, record which path was active:

```text
CORS evidence:
- bucket CORS set result:
- global api cors_allow_origin fallback used: yes/no
- strict-mode preflight result from 44-check-hf-ui.sh:
- browser direct upload result:
```

## Smoke Upload Cleanup Recommendation

Cleanup is recommended after evidence capture, but not before the report has the
uploaded object path and browser result. The automated checks intentionally write
timestamped objects under `smoke/` and do not delete them, which is useful for
auditability during a readiness wave but will accumulate stale catalog objects.

Recommended policy:

- Keep the final full-pass browser upload object for the release evidence
  window.
- Remove older `smoke/` uploads from `lab-datasets/demo/sentiment-mini/v1/` and
  `lab-models/demo/tiny-transformer/v1/` after the report is accepted.
- Do not delete seeded sample files such as `train.jsonl`, `validation.csv`,
  `test.json`, `sample.parquet`, `README.md`, or `model.safetensors`.

Concrete cleanup command after signoff, scoped to browser and direct-upload
smoke objects only:

```bash
sudo bash -lc '
set -a
. /opt/lab-stack/env/00-global.env
. /opt/lab-stack/env/10-core.env
. /opt/lab-stack/env/35-minio-storage.env
set +a
docker run --rm --network "$LABSTACK_DATA_NETWORK" \
  -e "MINIO_ROOT_USER=${MINIO_ROOT_USER}" \
  -e "MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}" \
  --entrypoint /bin/sh "${MINIO_MC_IMAGE:-minio/mc:latest}" \
  -c '"'"'
mc alias set labminio http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null
mc rm --recursive --force labminio/lab-datasets/demo/sentiment-mini/v1/smoke/
mc rm --recursive --force labminio/lab-models/demo/tiny-transformer/v1/smoke/
'"'"'
'
```

## Full-Pass Gate

Full pass can be recorded only when all of these are true:

- Strict-mode Phase 4, Phase 5, backup, and integrated checks pass on real
  DNS/TLS.
- MinIO Console browser evidence covers `lab-admin`, `lab-member`,
  `lab-collab` when sampled, and `lab-guest`.
- MinIO public/private bucket browser evidence confirms anonymous public
  download and anonymous private denial.
- HF UI browser evidence covers OIDC login, model/dataset list and detail,
  JSONL/CSV/JSON/Parquet previews, upload, overwrite block, overwrite success,
  download, unsupported file behavior, and `lab-guest` denial.
- CORS evidence states whether bucket CORS or global `api cors_allow_origin`
  handled direct browser PUT, and strict preflight passed.
- Smoke upload cleanup is either completed after report acceptance or explicitly
  deferred with the retained object path and retention reason.
