#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

parse_common_args "$@"
load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/70-overleaf.env"

OVERLEAF_MONGO_CONTAINER="${OVERLEAF_MONGO_CONTAINER:-overleaf-mongo}"
OVERLEAF_MONGO_RS="${OVERLEAF_MONGO_RS:-overleaf-rs}"
OVERLEAF_MONGO_RS_HOST="${OVERLEAF_MONGO_RS_HOST:-overleaf-mongo:27017}"

require_cmd docker

if is_dry_run; then
  cat <<DRYRUN
+ docker exec $OVERLEAF_MONGO_CONTAINER mongosh --quiet --eval 'rs.initiate({_id:"$OVERLEAF_MONGO_RS",members:[{_id:0,host:"$OVERLEAF_MONGO_RS_HOST"}]})'
+ docker exec $OVERLEAF_MONGO_CONTAINER mongosh --quiet --eval 'rs.status().ok'
DRYRUN
  exit 0
fi

if ! docker inspect "$OVERLEAF_MONGO_CONTAINER" >/dev/null 2>&1; then
  die "missing container: $OVERLEAF_MONGO_CONTAINER"
fi

init_js="
const cfg = {_id: \"$OVERLEAF_MONGO_RS\", members: [{_id: 0, host: \"$OVERLEAF_MONGO_RS_HOST\"}]};
try {
  const status = rs.status();
  if (status.ok === 1) {
    print(\"replica set already initialized\");
    quit(0);
  }
} catch (err) {
  if (!String(err).includes(\"no replset config has been received\") &&
      !String(err).includes(\"NotYetInitialized\")) {
    print(err);
  }
}
printjson(rs.initiate(cfg));
"

docker exec "$OVERLEAF_MONGO_CONTAINER" mongosh --quiet --eval "$init_js"

for _ in {1..30}; do
  if docker exec "$OVERLEAF_MONGO_CONTAINER" mongosh --quiet --eval 'rs.status().ok' | grep -q 1; then
    log "Overleaf Mongo replica set is ready"
    exit 0
  fi
  sleep 2
done

die "Overleaf Mongo replica set did not become ready"
