# Deployment Env Files

Phase 1 is repo + dry-run only. Keep tracked files as examples with placeholders, and do not add real secrets, generated client secrets, access keys, tokens, private keys, activation URLs, or production SMTP credentials.

For a later real host deployment, copy each active `*.env.example` file to `/opt/lab-stack/env/*.env` and replace placeholders on the server. Plane, Gitea, Nextcloud, and MLflow env examples are historical reference only for Phase 1 and are not part of the active Huly workspace MVP env surface.

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
MinIO user/key rotation remains an explicit maintenance action, not a repo change.

`99-demo.env` is staging-only. It stores temporary demo login data and must not be committed.
