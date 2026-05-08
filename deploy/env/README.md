# Deployment Env Files

Copy each `*.env.example` file to `/srv/lab-platform/env/*.env` and replace placeholders on the server.

Recommended permissions:

```bash
sudo install -d -m 0750 /srv/lab-platform/env
sudo chown -R root:lab-ops /srv/lab-platform/env
sudo chmod 0640 /srv/lab-platform/env/*.env
```

For a single-operator host, use `root:root` and `0600`.

Compose commands should explicitly load only the env files required by the module. Later env files can override earlier ones, so keep variable names service-scoped unless a value is intentionally global.

After adding a new service env file, re-run the relevant bootstrap scripts so server-side state matches the env values:

```bash
sudo /srv/lab-platform/scripts/02-bootstrap-postgres.sh
sudo /srv/lab-platform/scripts/08-create-minio-service-users.sh
```

Generated Authentik client secrets and MinIO access keys belong only in `/srv/lab-platform/env/*.env`.
`08-create-minio-service-users.sh` creates missing MinIO users and re-attaches policies; rotate an existing MinIO access key as an explicit maintenance action.
