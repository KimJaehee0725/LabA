#!/usr/bin/env bash
set -euo pipefail

LAB_PLATFORM_ROOT="${LAB_PLATFORM_ROOT:-/srv/lab-platform}"
DRY_RUN="${DRY_RUN:-false}"

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
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/logs/nginx
run install -d -m 0750 "$LAB_PLATFORM_ROOT"/env
run install -d -m 0700 "$LAB_PLATFORM_ROOT"/nginx/ssl

if compgen -G "$LAB_PLATFORM_ROOT/env/*.env" >/dev/null; then
  run chmod 0640 "$LAB_PLATFORM_ROOT"/env/*.env
fi
