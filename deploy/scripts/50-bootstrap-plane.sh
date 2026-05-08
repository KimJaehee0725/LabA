#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/40-plane.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

PLANE_CONTAINER="${PLANE_CONTAINER:-plane-api}"

docker exec "$PLANE_CONTAINER" python manage.py register_instance lab-platform >/dev/null
docker exec "$PLANE_CONTAINER" python manage.py configure_instance >/dev/null
docker exec \
  -e "PLANE_INSTANCE_NAME=${PLANE_INSTANCE_NAME:-Lab Plane}" \
  -e "PLANE_WEB_URL=${PLANE_WEB_URL:-https://lab.snu.ac.kr}" \
  "$PLANE_CONTAINER" python manage.py shell -c '
import os
from django.utils import timezone
from plane.license.models import Instance

instance = Instance.objects.first()
if instance is None:
    raise SystemExit("plane instance row is missing after register_instance")

instance.is_setup_done = True
instance.instance_name = os.environ["PLANE_INSTANCE_NAME"]
instance.domain = os.environ["PLANE_WEB_URL"]
instance.is_telemetry_enabled = False
instance.is_support_required = False
instance.last_checked_at = timezone.now()
instance.save()
'

echo "plane instance bootstrap completed"
