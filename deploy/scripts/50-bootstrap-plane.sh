#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/40-plane.env" "$ENV_DIR/80-minio-policies.env"
require_cmd docker

PLANE_CONTAINER="${PLANE_CONTAINER:-plane-api}"
PLANE_OIDC_DISCOVERY_URL="${PLANE_OIDC_DISCOVERY_URL:-https://${AUTH_DOMAIN:-auth.lab.snu.ac.kr}/application/o/plane/.well-known/openid-configuration}"
PLANE_OIDC_CLIENT_ID="${PLANE_OIDC_CLIENT_ID:-plane}"
PLANE_OIDC_CLIENT_SECRET="${PLANE_OIDC_CLIENT_SECRET:-}"
PLANE_OIDC_SCOPES="${PLANE_OIDC_SCOPES:-openid email profile groups}"
PLANE_OIDC_VERIFY_SSL="${PLANE_OIDC_VERIFY_SSL:-1}"
PLANE_OIDC_PROVIDER_LABEL="${PLANE_OIDC_PROVIDER_LABEL:-Authentik}"

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

docker exec \
  -e "PLANE_OIDC_DISCOVERY_URL=${PLANE_OIDC_DISCOVERY_URL}" \
  -e "PLANE_OIDC_CLIENT_ID=${PLANE_OIDC_CLIENT_ID}" \
  -e "PLANE_OIDC_CLIENT_SECRET=${PLANE_OIDC_CLIENT_SECRET}" \
  -e "PLANE_OIDC_SCOPES=${PLANE_OIDC_SCOPES}" \
  -e "PLANE_OIDC_VERIFY_SSL=${PLANE_OIDC_VERIFY_SSL}" \
  -e "PLANE_OIDC_PROVIDER_LABEL=${PLANE_OIDC_PROVIDER_LABEL}" \
  "$PLANE_CONTAINER" python manage.py shell -c '
import os

from plane.license.models import InstanceConfiguration
from plane.license.utils.encryption import encrypt_data

oidc_config = [
    {
        "key": "OIDC_DISCOVERY_URL",
        "env": "PLANE_OIDC_DISCOVERY_URL",
        "default": "",
        "is_encrypted": False,
    },
    {
        "key": "OIDC_CLIENT_ID",
        "env": "PLANE_OIDC_CLIENT_ID",
        "default": "",
        "is_encrypted": False,
    },
    {
        "key": "OIDC_CLIENT_SECRET",
        "env": "PLANE_OIDC_CLIENT_SECRET",
        "default": "",
        "is_encrypted": True,
    },
    {
        "key": "OIDC_SCOPES",
        "env": "PLANE_OIDC_SCOPES",
        "default": "openid email profile groups",
        "is_encrypted": False,
    },
    {
        "key": "OIDC_VERIFY_SSL",
        "env": "PLANE_OIDC_VERIFY_SSL",
        "default": "1",
        "is_encrypted": False,
    },
    {
        "key": "OIDC_PROVIDER_LABEL",
        "env": "PLANE_OIDC_PROVIDER_LABEL",
        "default": "Authentik",
        "is_encrypted": False,
    },
]

synced = []
for item in oidc_config:
    value = os.environ.get(item["env"], item["default"])
    stored_value = encrypt_data(value) if item["is_encrypted"] else value
    InstanceConfiguration.objects.update_or_create(
        key=item["key"],
        defaults={
            "value": stored_value,
            "category": "OIDC",
            "is_encrypted": item["is_encrypted"],
        },
    )
    synced.append(item["key"])

print("Plane OIDC instance configuration synced: " + ", ".join(synced))
'

echo "plane instance bootstrap completed"
