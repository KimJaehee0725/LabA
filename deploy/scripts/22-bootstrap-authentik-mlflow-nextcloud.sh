#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/10-core.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/50-mlflow.env" \
  "$ENV_DIR/60-nextcloud.env"

require_cmd docker
require_cmd mktemp

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
AUTH_URL="${AUTH_URL:-https://${AUTH_DOMAIN:-auth.lab.snu.ac.kr}}"
APP_POLICY_NAME="${APP_POLICY_NAME:-require-active-lab-user}"

NEXTCLOUD_OIDC_CLIENT_ID="${NEXTCLOUD_OIDC_CLIENT_ID:-nextcloud}"
NEXTCLOUD_OIDC_CLIENT_SECRET="${NEXTCLOUD_OIDC_CLIENT_SECRET:-}"
NEXTCLOUD_OIDC_APP_SLUG="${NEXTCLOUD_OIDC_APP_SLUG:-nextcloud}"
NEXTCLOUD_OIDC_APP_NAME="${NEXTCLOUD_OIDC_APP_NAME:-Nextcloud}"
NEXTCLOUD_OIDC_REDIRECT_URI="${NEXTCLOUD_OIDC_REDIRECT_URI:-https://${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}/apps/user_oidc/code}"

MLFLOW_PROXY_PROVIDER_NAME="${MLFLOW_PROXY_PROVIDER_NAME:-mlflow-proxy}"
MLFLOW_APP_SLUG="${MLFLOW_APP_SLUG:-mlflow}"
MLFLOW_APP_NAME="${MLFLOW_APP_NAME:-MLflow}"
MLFLOW_EXTERNAL_HOST="${MLFLOW_EXTERNAL_HOST:-https://${MLFLOW_DOMAIN:-mlflow.lab.snu.ac.kr}}"
MLFLOW_INTERNAL_HOST="${MLFLOW_INTERNAL_HOST:-http://mlflow:5000}"
MLFLOW_OUTPOST_NAME="${MLFLOW_OUTPOST_NAME:-mlflow-outpost}"
MLFLOW_OUTPOST_TOKEN_ENV_FILE="${MLFLOW_OUTPOST_TOKEN_ENV_FILE:-$ENV_DIR/50-mlflow.env}"
AUTHENTIK_UPDATE_MLFLOW_ENV="${AUTHENTIK_UPDATE_MLFLOW_ENV:-true}"
authentik_output="$(mktemp)"
chmod 0600 "$authentik_output"
trap 'rm -f "$authentik_output"' EXIT

if [[ -z "$NEXTCLOUD_OIDC_CLIENT_SECRET" || "$NEXTCLOUD_OIDC_CLIENT_SECRET" == change-me* ]]; then
  die "set NEXTCLOUD_OIDC_CLIENT_SECRET in $ENV_DIR/60-nextcloud.env before bootstrapping Nextcloud OIDC"
fi

update_env_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp mode owner group

  [[ -f "$file" ]] || die "env file not found: $file"
  tmp="$(mktemp "${file}.XXXXXX")"
  mode="$(stat -c '%a' "$file")"
  owner="$(stat -c '%u' "$file")"
  group="$(stat -c '%g' "$file")"

  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      updated = 1
      next
    }
    { print }
    END {
      if (updated == 0) {
        print key "=" value
      }
    }
  ' "$file" >"$tmp"
  chmod "$mode" "$tmp"
  chown "$owner:$group" "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
}

docker exec \
  -e "AUTH_URL=${AUTH_URL}" \
  -e "APP_POLICY_NAME=${APP_POLICY_NAME}" \
  -e "NEXTCLOUD_OIDC_CLIENT_ID=${NEXTCLOUD_OIDC_CLIENT_ID}" \
  -e "NEXTCLOUD_OIDC_CLIENT_SECRET=${NEXTCLOUD_OIDC_CLIENT_SECRET}" \
  -e "NEXTCLOUD_OIDC_APP_SLUG=${NEXTCLOUD_OIDC_APP_SLUG}" \
  -e "NEXTCLOUD_OIDC_APP_NAME=${NEXTCLOUD_OIDC_APP_NAME}" \
  -e "NEXTCLOUD_OIDC_REDIRECT_URI=${NEXTCLOUD_OIDC_REDIRECT_URI}" \
  -e "MLFLOW_PROXY_PROVIDER_NAME=${MLFLOW_PROXY_PROVIDER_NAME}" \
  -e "MLFLOW_APP_SLUG=${MLFLOW_APP_SLUG}" \
  -e "MLFLOW_APP_NAME=${MLFLOW_APP_NAME}" \
  -e "MLFLOW_EXTERNAL_HOST=${MLFLOW_EXTERNAL_HOST}" \
  -e "MLFLOW_INTERNAL_HOST=${MLFLOW_INTERNAL_HOST}" \
  -e "MLFLOW_OUTPOST_NAME=${MLFLOW_OUTPOST_NAME}" \
  "$AUTHENTIK_WORKER_CONTAINER" ak shell -c '
import os

from authentik.core.models import Application
from authentik.flows.models import Flow
from authentik.outposts.models import Outpost, OutpostConfig, OutpostType
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
from authentik.providers.proxy.models import ProxyMode, ProxyProvider

auth_url = os.environ["AUTH_URL"].rstrip("/")
policy_name = os.environ["APP_POLICY_NAME"]
policy = ExpressionPolicy.objects.get(name=policy_name)
authorization_flow = Flow.objects.get(slug="default-provider-authorization-implicit-consent")
invalidation_flow = Flow.objects.get(slug="default-provider-invalidation-flow")


def bind_policy(application):
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


def oidc_scope_mappings():
    mappings = []
    for scope_name in ["openid", "email", "profile"]:
        mapping = ScopeMapping.objects.filter(scope_name=scope_name).first()
        if mapping is None:
            raise SystemExit(f"missing Authentik OAuth2 scope mapping: {scope_name}")
        mappings.append(mapping)
    groups_mapping, _ = ScopeMapping.objects.update_or_create(
        name="lab-groups",
        defaults={
            "scope_name": "groups",
            "description": "Add Authentik group names to OIDC claims.",
            "expression": "return {\n    \"groups\": [group.name for group in user.ak_groups.all()],\n}",
        },
    )
    mappings.append(groups_mapping)
    return mappings


nextcloud_provider = (
    OAuth2Provider.objects.filter(name=os.environ["NEXTCLOUD_OIDC_APP_SLUG"]).first()
    or OAuth2Provider.objects.filter(client_id=os.environ["NEXTCLOUD_OIDC_CLIENT_ID"]).first()
    or OAuth2Provider(name=os.environ["NEXTCLOUD_OIDC_APP_SLUG"])
)
nextcloud_provider.name = os.environ["NEXTCLOUD_OIDC_APP_SLUG"]
nextcloud_provider.authorization_flow = authorization_flow
nextcloud_provider.invalidation_flow = invalidation_flow
nextcloud_provider.client_type = ClientTypes.CONFIDENTIAL
nextcloud_provider.client_id = os.environ["NEXTCLOUD_OIDC_CLIENT_ID"]
nextcloud_provider.client_secret = os.environ["NEXTCLOUD_OIDC_CLIENT_SECRET"]
nextcloud_provider.include_claims_in_id_token = True
nextcloud_provider.issuer_mode = IssuerMode.PER_PROVIDER
nextcloud_provider.redirect_uris = [
    RedirectURI(RedirectURIMatchingMode.STRICT, os.environ["NEXTCLOUD_OIDC_REDIRECT_URI"]),
]
nextcloud_provider.save()
nextcloud_provider.property_mappings.set(oidc_scope_mappings())

nextcloud_application, _ = Application.objects.get_or_create(
    slug=os.environ["NEXTCLOUD_OIDC_APP_SLUG"],
    defaults={
        "name": os.environ["NEXTCLOUD_OIDC_APP_NAME"],
        "meta_launch_url": os.environ["NEXTCLOUD_OIDC_REDIRECT_URI"].split("/apps/user_oidc/code")[0],
    },
)
nextcloud_application.name = os.environ["NEXTCLOUD_OIDC_APP_NAME"]
nextcloud_application.meta_launch_url = os.environ["NEXTCLOUD_OIDC_REDIRECT_URI"].split("/apps/user_oidc/code")[0]
nextcloud_application.provider = nextcloud_provider
nextcloud_application.save()
bind_policy(nextcloud_application)

mlflow_provider = (
    ProxyProvider.objects.filter(name=os.environ["MLFLOW_PROXY_PROVIDER_NAME"]).first()
    or ProxyProvider(name=os.environ["MLFLOW_PROXY_PROVIDER_NAME"])
)
mlflow_provider.name = os.environ["MLFLOW_PROXY_PROVIDER_NAME"]
mlflow_provider.authorization_flow = authorization_flow
mlflow_provider.invalidation_flow = invalidation_flow
mlflow_provider.external_host = os.environ["MLFLOW_EXTERNAL_HOST"].rstrip("/")
mlflow_provider.internal_host = ""
mlflow_provider.internal_host_ssl_validation = False
mlflow_provider.mode = ProxyMode.FORWARD_SINGLE
mlflow_provider.cookie_domain = os.environ["MLFLOW_EXTERNAL_HOST"].split("://", 1)[-1].split("/", 1)[0]
mlflow_provider.save()
mlflow_provider.set_oauth_defaults()
mlflow_provider.save()

mlflow_application, _ = Application.objects.get_or_create(
    slug=os.environ["MLFLOW_APP_SLUG"],
    defaults={
        "name": os.environ["MLFLOW_APP_NAME"],
        "meta_launch_url": os.environ["MLFLOW_EXTERNAL_HOST"],
    },
)
mlflow_application.name = os.environ["MLFLOW_APP_NAME"]
mlflow_application.meta_launch_url = os.environ["MLFLOW_EXTERNAL_HOST"]
mlflow_application.provider = mlflow_provider
mlflow_application.save()
bind_policy(mlflow_application)

outpost, _ = Outpost.objects.get_or_create(
    name=os.environ["MLFLOW_OUTPOST_NAME"],
    defaults={
        "type": OutpostType.PROXY,
        "service_connection": None,
    },
)
outpost.type = OutpostType.PROXY
outpost.service_connection = None
outpost.config = OutpostConfig(
    authentik_host=auth_url,
    authentik_host_insecure=False,
    docker_map_ports=False,
    docker_network="lab_backend",
)
outpost.save()
outpost.providers.set([mlflow_provider])
outpost.build_user_permissions(outpost.user)

print("MLFLOW_OUTPOST_TOKEN=" + outpost.token.key)
' >"$authentik_output"

mlflow_outpost_token="$(awk -F= '/^MLFLOW_OUTPOST_TOKEN=/ {print $2}' "$authentik_output" | tail -n 1)"
rm -f "$authentik_output"
trap - EXIT

if [[ -z "$mlflow_outpost_token" ]]; then
  die "failed to read generated MLflow outpost token from Authentik"
fi

if [[ "$AUTHENTIK_UPDATE_MLFLOW_ENV" == "true" ]]; then
  update_env_value "$MLFLOW_OUTPOST_TOKEN_ENV_FILE" "AUTHENTIK_OUTPOST_MLFLOW_TOKEN" "$mlflow_outpost_token"
  log "updated AUTHENTIK_OUTPOST_MLFLOW_TOKEN in $MLFLOW_OUTPOST_TOKEN_ENV_FILE"
else
  log "AUTHENTIK_UPDATE_MLFLOW_ENV=false; MLflow outpost token was generated but not written"
fi

log "authentik Nextcloud OIDC and MLflow proxy bootstrap completed"
