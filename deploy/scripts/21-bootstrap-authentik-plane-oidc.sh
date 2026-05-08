#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env" "$ENV_DIR/40-plane.env"
require_cmd docker

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
AUTH_URL="${AUTH_URL:-https://auth.lab.snu.ac.kr}"
PLANE_WEB_URL="${PLANE_WEB_URL:-https://lab.snu.ac.kr}"
PLANE_OIDC_CLIENT_ID="${PLANE_OIDC_CLIENT_ID:-plane}"
PLANE_OIDC_SCOPES="${PLANE_OIDC_SCOPES:-openid email profile groups}"
PLANE_OIDC_PROVIDER_LABEL="${PLANE_OIDC_PROVIDER_LABEL:-Authentik}"
PLANE_OIDC_APP_SLUG="${PLANE_OIDC_APP_SLUG:-plane}"
PLANE_OIDC_APP_NAME="${PLANE_OIDC_APP_NAME:-Plane}"
PLANE_OIDC_POLICY_NAME="${PLANE_OIDC_POLICY_NAME:-require-active-lab-user}"
PLANE_OIDC_REDIRECT_URI="${PLANE_OIDC_REDIRECT_URI:-${PLANE_WEB_URL%/}/auth/oidc/callback/}"
EXPECTED_DISCOVERY_URL="${AUTH_URL%/}/application/o/${PLANE_OIDC_APP_SLUG}/.well-known/openid-configuration"

if [[ "${PLANE_OIDC_CLIENT_SECRET:-}" == "" || "${PLANE_OIDC_CLIENT_SECRET:-}" == change-me* ]]; then
  die "set PLANE_OIDC_CLIENT_SECRET in $ENV_DIR/40-plane.env before bootstrapping Plane OIDC"
fi

if [[ "${PLANE_OIDC_DISCOVERY_URL:-$EXPECTED_DISCOVERY_URL}" != "$EXPECTED_DISCOVERY_URL" ]]; then
  die "PLANE_OIDC_DISCOVERY_URL must be $EXPECTED_DISCOVERY_URL for the Authentik application slug ${PLANE_OIDC_APP_SLUG}"
fi

docker exec \
  -e "PLANE_OIDC_CLIENT_ID=${PLANE_OIDC_CLIENT_ID}" \
  -e "PLANE_OIDC_CLIENT_SECRET=${PLANE_OIDC_CLIENT_SECRET}" \
  -e "PLANE_OIDC_SCOPES=${PLANE_OIDC_SCOPES}" \
  -e "PLANE_OIDC_PROVIDER_LABEL=${PLANE_OIDC_PROVIDER_LABEL}" \
  -e "PLANE_OIDC_APP_SLUG=${PLANE_OIDC_APP_SLUG}" \
  -e "PLANE_OIDC_APP_NAME=${PLANE_OIDC_APP_NAME}" \
  -e "PLANE_OIDC_POLICY_NAME=${PLANE_OIDC_POLICY_NAME}" \
  -e "PLANE_OIDC_REDIRECT_URI=${PLANE_OIDC_REDIRECT_URI}" \
  -e "PLANE_WEB_URL=${PLANE_WEB_URL}" \
  "$AUTHENTIK_WORKER_CONTAINER" ak shell -c '
import os

from authentik.core.models import Application
from authentik.flows.models import Flow
from authentik.policies.expression.models import ExpressionPolicy
from authentik.policies.models import PolicyBinding
from authentik.providers.oauth2.models import (
    ClientTypes,
    IssuerMode,
    OAuth2Provider,
    RedirectURI,
    RedirectURIMatchingMode,
    ScopeMapping,
)

client_id = os.environ["PLANE_OIDC_CLIENT_ID"]
client_secret = os.environ["PLANE_OIDC_CLIENT_SECRET"]
provider_label = os.environ["PLANE_OIDC_PROVIDER_LABEL"]
app_slug = os.environ["PLANE_OIDC_APP_SLUG"]
app_name = os.environ["PLANE_OIDC_APP_NAME"]
policy_name = os.environ["PLANE_OIDC_POLICY_NAME"]
redirect_uri = os.environ["PLANE_OIDC_REDIRECT_URI"]
launch_url = os.environ["PLANE_WEB_URL"]

authorization_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
invalidation_flow = Flow.objects.get(slug="default-provider-invalidation-flow")

provider = (
    OAuth2Provider.objects.filter(name=app_slug).first()
    or OAuth2Provider.objects.filter(client_id=client_id).first()
    or OAuth2Provider(name=app_slug)
)
provider.name = app_slug
provider.authorization_flow = authorization_flow
provider.invalidation_flow = invalidation_flow
provider.client_type = ClientTypes.CONFIDENTIAL
provider.client_id = client_id
provider.client_secret = client_secret
provider.include_claims_in_id_token = True
provider.issuer_mode = IssuerMode.PER_PROVIDER
provider.redirect_uris = [
    RedirectURI(RedirectURIMatchingMode.STRICT, redirect_uri),
]
provider.save()

required_scopes = ["openid", "email", "profile"]
scope_mappings = []
for scope_name in required_scopes:
    mapping = ScopeMapping.objects.filter(scope_name=scope_name).first()
    if mapping is None:
        raise SystemExit(f"missing Authentik OAuth2 scope mapping: {scope_name}")
    scope_mappings.append(mapping)

groups_mapping, _ = ScopeMapping.objects.update_or_create(
    name="lab-groups",
    defaults={
        "scope_name": "groups",
        "description": "Add Authentik group names to OIDC claims.",
        "expression": "return {\n    \"groups\": [group.name for group in user.ak_groups.all()],\n}",
    },
)
scope_mappings.append(groups_mapping)
provider.property_mappings.set(scope_mappings)

application, _ = Application.objects.get_or_create(
    slug=app_slug,
    defaults={
        "name": app_name,
        "meta_launch_url": launch_url,
    },
)
application.name = app_name
application.meta_launch_url = launch_url
application.provider = provider
application.save()

policy = ExpressionPolicy.objects.get(name=policy_name)
binding, _ = PolicyBinding.objects.update_or_create(
    target=application,
    policy=policy,
    order=0,
    defaults={
        "enabled": True,
        "negate": False,
        "timeout": 30,
        "failure_result": False,
    },
)
PolicyBinding.objects.filter(target=application, policy=policy).exclude(
    policy_binding_uuid=binding.policy_binding_uuid
).delete()

print(f"Plane OIDC application ready: slug={app_slug}, label={provider_label}, redirect={redirect_uri}")
'

echo "authentik Plane OIDC bootstrap completed"
