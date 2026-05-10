#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/10-core.env" "$ENV_DIR/20-authentik.env"
require_cmd docker

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
AUTH_URL="${AUTH_URL:-https://${AUTH_DOMAIN}}"
AUTH_URL="${AUTH_URL%/}"
AUTHENTIK_PHASE2_OIDC_APPS="${AUTHENTIK_PHASE2_OIDC_APPS:-huly,minio,hf-ui}"
AUTHENTIK_OIDC_POLICY_NAME="${AUTHENTIK_OIDC_POLICY_NAME:-require-active-lab-user}"
AUTHENTIK_OIDC_AUTHORIZATION_FLOW="${AUTHENTIK_OIDC_AUTHORIZATION_FLOW:-default-provider-authorization-implicit-consent}"
AUTHENTIK_OIDC_INVALIDATION_FLOW="${AUTHENTIK_OIDC_INVALIDATION_FLOW:-default-provider-invalidation-flow}"
AUTHENTIK_OIDC_SCOPES="${AUTHENTIK_OIDC_SCOPES:-openid,email,profile,groups}"
AUTHENTIK_OIDC_BOOTSTRAP_RETRIES="${AUTHENTIK_OIDC_BOOTSTRAP_RETRIES:-12}"
AUTHENTIK_OIDC_BOOTSTRAP_SLEEP="${AUTHENTIK_OIDC_BOOTSTRAP_SLEEP:-5}"

is_placeholder_value() {
  local value="${1:-}"
  [[ -z "$value" || "$value" == change-me* || "$value" == CHANGE-ME* || "$value" == todo* || "$value" == TODO* ]]
}

require_value() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder_value "$value"; then
    die "$name must be set in $ENV_DIR/20-authentik.env before bootstrapping Phase 2 OIDC"
  fi
}

require_secret() {
  local name="$1"
  local value="${!name:-}"
  if is_placeholder_value "$value"; then
    die "$name must be generated and stored only in $ENV_DIR/20-authentik.env before bootstrapping Phase 2 OIDC"
  fi
}

bootstrap_app() {
  local slug="$1"
  local prefix app_name launch_url default_scopes

  case "$slug" in
    huly)
      prefix="HULY"
      app_name="${HULY_OIDC_APP_NAME:-Huly}"
      launch_url="${HULY_OIDC_LAUNCH_URL:-https://${HULY_DOMAIN}}"
      default_scopes="${HULY_OIDC_SCOPES:-$AUTHENTIK_OIDC_SCOPES}"
      ;;
    minio)
      prefix="MINIO"
      app_name="${MINIO_OIDC_APP_NAME:-MinIO Console}"
      launch_url="${MINIO_OIDC_LAUNCH_URL:-https://${FILES_DOMAIN}}"
      default_scopes="${MINIO_OIDC_SCOPES:-openid,email,profile,groups,policy}"
      ;;
    hf-ui)
      prefix="HF_UI"
      app_name="${HF_UI_OIDC_APP_NAME:-HF UI}"
      launch_url="${HF_UI_OIDC_LAUNCH_URL:-https://${HF_DOMAIN}}"
      default_scopes="${HF_UI_OIDC_SCOPES:-$AUTHENTIK_OIDC_SCOPES}"
      ;;
    *)
      die "unsupported Phase 2 OIDC app slug: $slug"
      ;;
  esac

  local client_id_var="${prefix}_OIDC_CLIENT_ID"
  local client_secret_var="${prefix}_OIDC_CLIENT_SECRET"
  local redirect_uris_var="${prefix}_OIDC_REDIRECT_URIS"

  require_value "$client_id_var"
  require_secret "$client_secret_var"
  require_value "$redirect_uris_var"

  local client_id="${!client_id_var}"
  local client_secret="${!client_secret_var}"
  local redirect_uris="${!redirect_uris_var}"
  local discovery_url="${AUTH_URL}/application/o/${slug}/.well-known/openid-configuration"
  local attempt

  for attempt in $(seq 1 "$AUTHENTIK_OIDC_BOOTSTRAP_RETRIES"); do
    if docker exec \
      -e "OIDC_APP_SLUG=${slug}" \
      -e "OIDC_APP_NAME=${app_name}" \
      -e "OIDC_APP_LAUNCH_URL=${launch_url}" \
      -e "OIDC_CLIENT_ID=${client_id}" \
      -e "OIDC_CLIENT_SECRET=${client_secret}" \
      -e "OIDC_REDIRECT_URIS=${redirect_uris}" \
      -e "OIDC_POLICY_NAME=${AUTHENTIK_OIDC_POLICY_NAME}" \
      -e "OIDC_AUTHORIZATION_FLOW=${AUTHENTIK_OIDC_AUTHORIZATION_FLOW}" \
      -e "OIDC_INVALIDATION_FLOW=${AUTHENTIK_OIDC_INVALIDATION_FLOW}" \
      -e "OIDC_SCOPES=${default_scopes}" \
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

app_slug = os.environ["OIDC_APP_SLUG"]
app_name = os.environ["OIDC_APP_NAME"]
launch_url = os.environ["OIDC_APP_LAUNCH_URL"]
client_id = os.environ["OIDC_CLIENT_ID"]
client_secret = os.environ["OIDC_CLIENT_SECRET"]
redirect_uris = [
    uri.strip()
    for uri in os.environ["OIDC_REDIRECT_URIS"].split(",")
    if uri.strip()
]
policy_name = os.environ["OIDC_POLICY_NAME"]
authorization_flow_slug = os.environ["OIDC_AUTHORIZATION_FLOW"]
invalidation_flow_slug = os.environ["OIDC_INVALIDATION_FLOW"]
scope_names = [
    scope.strip()
    for scope in os.environ["OIDC_SCOPES"].replace(" ", ",").split(",")
    if scope.strip()
]

if not redirect_uris:
    raise SystemExit("at least one redirect URI is required")
for uri in redirect_uris:
    if not uri.startswith("https://"):
        raise SystemExit(f"redirect URI must use https: {uri}")

authorization_flow = Flow.objects.get(slug=authorization_flow_slug)
invalidation_flow = Flow.objects.get(slug=invalidation_flow_slug)
policy = ExpressionPolicy.objects.get(name=policy_name)

if app_slug == "minio":
    ScopeMapping.objects.update_or_create(
        name="lab-minio-policy",
        defaults={
            "scope_name": "policy",
            "description": "Map Authentik lab groups to MinIO policy names.",
            "expression": """groups = {group.name for group in user.ak_groups.all()}
if "lab-admin" in groups:
    policy = "consoleAdmin"
elif {"lab-member", "lab-collab"}.intersection(groups):
    policy = "lab-storage-member-rw"
else:
    policy = ""
return {"policy": policy}
""",
        },
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
provider.redirect_uris = [
    RedirectURI(RedirectURIMatchingMode.STRICT, uri)
    for uri in redirect_uris
]
provider.save()

scope_mappings = []
for scope_name in scope_names:
    if app_slug == "minio" and scope_name == "policy":
        mapping = ScopeMapping.objects.filter(name="lab-minio-policy").first()
    else:
        mapping = ScopeMapping.objects.filter(scope_name=scope_name).first()
    if mapping is None:
        raise SystemExit(f"missing Authentik OAuth2 scope mapping: {scope_name}")
    scope_mappings.append(mapping)
provider.property_mappings.set(scope_mappings)

application, _ = Application.objects.get_or_create(
    slug=app_slug,
    defaults={"name": app_name, "meta_launch_url": launch_url},
)
application.name = app_name
application.meta_launch_url = launch_url
application.provider = provider
application.save()

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

print(f"OIDC application ready: slug={app_slug}, client_id={client_id}, redirects={len(redirect_uris)}, scopes={scope_names}")
'; then
      log "OIDC discovery URL for ${slug}: ${discovery_url}"
      return 0
    fi

    if [[ "$attempt" -lt "$AUTHENTIK_OIDC_BOOTSTRAP_RETRIES" ]]; then
      log "OIDC bootstrap for ${slug} failed; retrying after ${AUTHENTIK_OIDC_BOOTSTRAP_SLEEP}s"
      sleep "$AUTHENTIK_OIDC_BOOTSTRAP_SLEEP"
    fi
  done

  die "OIDC bootstrap failed for ${slug} after ${AUTHENTIK_OIDC_BOOTSTRAP_RETRIES} attempts"
}

IFS=',' read -r -a phase2_apps <<<"$AUTHENTIK_PHASE2_OIDC_APPS"
for app in "${phase2_apps[@]}"; do
  app="${app//[[:space:]]/}"
  [[ -n "$app" ]] || continue
  bootstrap_app "$app"
done

log "phase2 Authentik OIDC bootstrap completed"
