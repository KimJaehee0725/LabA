#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/65-grist.env"

require_cmd docker

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
AUTH_URL="${AUTH_URL:-https://${AUTH_DOMAIN:-auth.lab.snu.ac.kr}}"
GRIST_OIDC_APP_SLUG="${GRIST_OIDC_APP_SLUG:-grist}"
GRIST_OIDC_APP_NAME="${GRIST_OIDC_APP_NAME:-Grist}"
GRIST_OIDC_CLIENT_ID="${GRIST_OIDC_CLIENT_ID:-grist}"
GRIST_OIDC_POLICY_NAME="${GRIST_OIDC_POLICY_NAME:-require-active-lab-user}"
GRIST_OIDC_REDIRECT_URI="${GRIST_OIDC_REDIRECT_URI:-https://${GRIST_DOMAIN:-data.lab.snu.ac.kr}/oauth2/callback}"
AUTHENTIK_OIDC_SIGNING_KEY_NAME="${AUTHENTIK_OIDC_SIGNING_KEY_NAME:-authentik Self-signed Certificate}"
EXPECTED_ISSUER="${AUTH_URL%/}/application/o/${GRIST_OIDC_APP_SLUG}/"

if [[ -z "${GRIST_OIDC_CLIENT_SECRET:-}" || "${GRIST_OIDC_CLIENT_SECRET:-}" == change-me* ]]; then
  die "set GRIST_OIDC_CLIENT_SECRET in $ENV_DIR/65-grist.env before bootstrapping Grist OIDC"
fi

if [[ "${GRIST_OIDC_IDP_ISSUER:-$EXPECTED_ISSUER}" != "$EXPECTED_ISSUER" ]]; then
  die "GRIST_OIDC_IDP_ISSUER must be $EXPECTED_ISSUER for the Authentik application slug ${GRIST_OIDC_APP_SLUG}"
fi

docker exec \
  -e "GRIST_OIDC_APP_SLUG=${GRIST_OIDC_APP_SLUG}" \
  -e "GRIST_OIDC_APP_NAME=${GRIST_OIDC_APP_NAME}" \
  -e "GRIST_OIDC_CLIENT_ID=${GRIST_OIDC_CLIENT_ID}" \
  -e "GRIST_OIDC_CLIENT_SECRET=${GRIST_OIDC_CLIENT_SECRET}" \
  -e "GRIST_OIDC_POLICY_NAME=${GRIST_OIDC_POLICY_NAME}" \
  -e "GRIST_OIDC_REDIRECT_URI=${GRIST_OIDC_REDIRECT_URI}" \
  -e "GRIST_LAUNCH_URL=https://${GRIST_DOMAIN:-data.lab.snu.ac.kr}" \
  -e "AUTHENTIK_OIDC_SIGNING_KEY_NAME=${AUTHENTIK_OIDC_SIGNING_KEY_NAME}" \
  "$AUTHENTIK_WORKER_CONTAINER" ak shell -c '
import os

from authentik.core.models import Application
from authentik.crypto.models import CertificateKeyPair
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

app_slug = os.environ["GRIST_OIDC_APP_SLUG"]
app_name = os.environ["GRIST_OIDC_APP_NAME"]
client_id = os.environ["GRIST_OIDC_CLIENT_ID"]
client_secret = os.environ["GRIST_OIDC_CLIENT_SECRET"]
policy_name = os.environ["GRIST_OIDC_POLICY_NAME"]
redirect_uri = os.environ["GRIST_OIDC_REDIRECT_URI"]
launch_url = os.environ["GRIST_LAUNCH_URL"]

authorization_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
invalidation_flow = Flow.objects.get(slug="default-provider-invalidation-flow")
signing_key = CertificateKeyPair.objects.filter(
    name=os.environ["AUTHENTIK_OIDC_SIGNING_KEY_NAME"]
).first()
if signing_key is None:
    raise SystemExit(
        f"missing Authentik signing key: {os.environ['AUTHENTIK_OIDC_SIGNING_KEY_NAME']}"
    )

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
provider.signing_key = signing_key
provider.redirect_uris = [
    RedirectURI(RedirectURIMatchingMode.STRICT, redirect_uri),
]
provider.save()

scope_mappings = []
for scope_name in ["openid", "email", "profile"]:
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
    defaults={"name": app_name, "meta_launch_url": launch_url},
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

print(f"Grist OIDC application ready: slug={app_slug}, redirect={redirect_uri}")
'

echo "authentik Grist OIDC bootstrap completed"
