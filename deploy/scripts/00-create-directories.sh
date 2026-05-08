#!/usr/bin/env bash
set -euo pipefail

LAB_PLATFORM_ROOT="${LAB_PLATFORM_ROOT:-/srv/lab-platform}"
DRY_RUN="${DRY_RUN:-false}"
AUTHENTIK_CONTAINER_UID="${AUTHENTIK_CONTAINER_UID:-1000}"
AUTHENTIK_CONTAINER_GID="${AUTHENTIK_CONTAINER_GID:-1000}"
GITEA_CONTAINER_UID="${GITEA_CONTAINER_UID:-1000}"
GITEA_CONTAINER_GID="${GITEA_CONTAINER_GID:-1000}"

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '+ %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run install -d -m 0750 "$LAB_PLATFORM_ROOT"
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/{compose,authentik/blueprints,gitea,minio/policies,data,logs,backups/archive,backups/scripts,nginx/conf.d,nginx/snippets}
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/data/{postgres,redis,minio,authentik,gitea,nextcloud,overleaf}
run install -d -m 0770 "$LAB_PLATFORM_ROOT"/data/authentik/{media,certs,custom-templates}
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/logs/nginx
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/env
run install -d -m 0700 "$LAB_PLATFORM_ROOT"/nginx/ssl

if [[ "$DRY_RUN" == "true" ]]; then
  echo "+ chown -R ${AUTHENTIK_CONTAINER_UID}:${AUTHENTIK_CONTAINER_GID} $LAB_PLATFORM_ROOT/data/authentik"
  echo "+ chown -R ${GITEA_CONTAINER_UID}:${GITEA_CONTAINER_GID} $LAB_PLATFORM_ROOT/data/gitea"
else
  chown -R "${AUTHENTIK_CONTAINER_UID}:${AUTHENTIK_CONTAINER_GID}" "$LAB_PLATFORM_ROOT"/data/authentik
  chown -R "${GITEA_CONTAINER_UID}:${GITEA_CONTAINER_GID}" "$LAB_PLATFORM_ROOT"/data/gitea
fi

if compgen -G "$LAB_PLATFORM_ROOT/env/*.env" >/dev/null; then
  run chmod 0640 "$LAB_PLATFORM_ROOT"/env/*.env
fi
