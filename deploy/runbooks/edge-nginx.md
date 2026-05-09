# Edge Nginx Runbook

## TLS

Nginx reads the edge certificate from:

```text
/srv/lab-platform/nginx/ssl/origin.crt
/srv/lab-platform/nginx/ssl/origin.key
```

For early smoke only, a self-signed leaf certificate is acceptable:

```bash
sudo /srv/lab-platform/scripts/05-create-self-signed-cert.sh
```

For staging with TLS verification enabled between services, create an internal root CA and a CA-signed origin certificate:

```bash
sudo /srv/lab-platform/scripts/05-create-internal-ca-cert.sh
openssl verify \
  -CAfile /srv/lab-platform/nginx/ssl/lab-internal-ca.crt \
  /srv/lab-platform/nginx/ssl/origin.crt
```

The internal CA script writes `/srv/lab-platform/nginx/ssl/origin.crt` as the leaf certificate followed by the CA chain. It backs up existing `origin.crt` and `origin.key` files with timestamp suffixes before replacing them.

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
