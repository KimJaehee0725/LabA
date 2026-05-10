# Deployment Env Files

Phase 1 is repo + dry-run only. Keep tracked files as examples with placeholders, and do not add real secrets, generated client secrets, access keys, tokens, private keys, activation URLs, or production SMTP credentials.

For a later real host deployment, copy each active `*.env.example` file to `/opt/lab-stack/env/*.env` and replace placeholders on the server. The active Huly workspace MVP env files are `00-global.env`, `10-core.env`, `20-authentik.env`, `30-huly.env`, `35-minio-storage.env`, `45-hf-ui.env`, and `70-overleaf.env` when Phase 6 Overleaf is enabled. Plane, Gitea, Nextcloud, and MLflow env examples are historical reference only for Phase 1 and are not part of the active Huly workspace MVP env surface.

Recommended permissions:

```bash
sudo install -d -m 0750 /opt/lab-stack/env
sudo chown -R root:lab-ops /opt/lab-stack/env
sudo chmod 0640 /opt/lab-stack/env/*.env
```

For a single-operator host, use `root:root` and `0600`.

Compose commands should explicitly load only the env files required by the module. Later env files can override earlier ones, so keep variable names service-scoped unless a value is intentionally global.

Phase 1 dry-runs may render or lint examples, but they should not start services or bootstrap server-side state. The active host skeleton networks are:

```text
labstack_public
labstack_backend
labstack_data
```

Generated Authentik client secrets and MinIO access keys belong only in `/opt/lab-stack/env/*.env`.
For Phase 2 full pass, set `HULY_OIDC_*`, `MINIO_OIDC_*`, and `HF_UI_OIDC_*`
only in `/opt/lab-stack/env/20-authentik.env`; the tracked example keeps
placeholder secrets so generated client secrets never enter git. Huly's Phase 3
callback is `https://$HULY_DOMAIN/_accounts/auth/openid/callback`.
MinIO's Phase 4 callback is `https://$FILES_DOMAIN/oauth_callback`; its
Console OIDC policy claim is named `policy` and maps `lab-admin` to
`consoleAdmin` and `lab-member`/`lab-collab` to `lab-storage-member-rw`.
HF-like UI's Phase 5 callback is `https://$HF_DOMAIN/oauth/callback`. Its
service access key should be attached only to `hf-ui-storage-rw`.
MinIO user/key rotation remains an explicit maintenance action, not a repo change.

For Phase 6, `70-overleaf.env` stores only Overleaf runtime settings. Use
generated values for `OVERLEAF_SESSION_SECRET` and `OVERLEAF_REDIS_PASSWORD`.
Keep SMTP credentials server-only and never record admin activation URLs in git,
history, reports, or shared chat.

For Phase 3, `30-huly.env` must use URL-safe generated values for CockroachDB,
Redpanda, MinIO, and `HULY_SERVER_SECRET`. GitHub App private keys and Google
OAuth credential JSON remain server-only. Prefer
`HULY_GITHUB_PRIVATE_KEY_FILE` and `HULY_GOOGLE_CALENDAR_CREDENTIALS_FILE`
under `/opt/lab-stack/secrets/huly/` instead of embedding PEM/JSON directly in
the env file.

`99-demo.env` is staging-only. It stores temporary demo login data and must not be committed.
