# Edge Nginx Runbook

## TLS Placeholder

Before starting Nginx, place cert files at:

```text
/srv/lab-platform/nginx/ssl/origin.crt
/srv/lab-platform/nginx/ssl/origin.key
```

For internal smoke only, a self-signed cert is acceptable.

## Start

```bash
cd /srv/lab-platform/compose/edge
docker compose \
  --env-file /srv/lab-platform/env/00-global.env \
  up -d
/srv/lab-platform/scripts/10-check-edge.sh
```

Only ports `80`, `443`, and Gitea SSH `2222` should be published.

## Rollback

Disable a single route by moving its `conf.d/*.conf` file out of the directory and reloading Nginx:

```bash
docker exec nginx nginx -s reload
```
