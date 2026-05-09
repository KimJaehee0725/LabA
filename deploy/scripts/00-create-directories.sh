#!/usr/bin/env bash
set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
# shellcheck source=lib/common.sh
. "$COMMON_DIR/common.sh"

parse_common_args "$@"

install_dirs=(
  "$LAB_STACK_ROOT"
  "$LAB_STACK_ROOT/env"
  "$LAB_STACK_ROOT/compose"
  "$LAB_STACK_ROOT/certs"
  "$LAB_STACK_ROOT/nginx"
  "$LAB_STACK_ROOT/nginx/conf.d"
  "$LAB_STACK_ROOT/nginx/snippets"
  "$LAB_STACK_ROOT/authentik"
  "$LAB_STACK_ROOT/huly"
  "$LAB_STACK_ROOT/minio"
  "$LAB_STACK_ROOT/hf-ui"
  "$LAB_STACK_ROOT/overleaf"
  "$LAB_STACK_ROOT/portal"
  "$LAB_STACK_ROOT/backups"
  "$LAB_STACK_ROOT/backups/archive"
  "$LAB_STACK_ROOT/backups/scripts"
  "$LAB_STACK_ROOT/logs"
  "$LAB_STACK_ROOT/logs/nginx"
)

for dir in "${install_dirs[@]}"; do
  run_cmd install -d -m 0750 "$dir"
done

run_cmd install -d -m 0700 "$LAB_STACK_ROOT/certs/private"

if compgen -G "$LAB_STACK_ROOT/env/*.env" >/dev/null; then
  env_files=("$LAB_STACK_ROOT"/env/*.env)
  run_cmd chmod 0640 "${env_files[@]}"
fi
