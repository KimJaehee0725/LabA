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

For the v0.2 Runtime Gate 1 stage, only ports `80` and `443` should be published.
Gitea SSH port `2222` is introduced later in the app wave, not during this gate.

## Rollback

Disable a single route by moving its `conf.d/*.conf` file out of the directory and reloading Nginx:

```bash
docker exec nginx nginx -s reload
```
