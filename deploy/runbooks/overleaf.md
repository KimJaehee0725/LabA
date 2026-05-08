# Overleaf Runbook

Overleaf CE uses manual accounts for v0.3. Authentik SSO is out of scope.

## Build And Start

```bash
cd /srv/lab-platform/compose/overleaf
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/70-overleaf.env \
  build
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  --env-file /srv/lab-platform/env/70-overleaf.env \
  up -d
```

Initialize Mongo replica set if needed:

```bash
docker exec overleaf-mongo mongosh --eval 'rs.initiate({_id:"overleaf-rs",members:[{_id:0,host:"mongo:27017"}]})'
```

Create admin:

```bash
docker exec overleaf grunt user:create-admin --email=admin@example.edu
```

Treat the activation URL as a secret.

## Smoke

Invite a user, compile a sample and Korean LaTeX project, clone project Git, then push a backup remote to Gitea.
