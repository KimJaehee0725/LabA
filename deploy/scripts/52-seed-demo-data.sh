#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs \
  "$ENV_DIR/00-global.env" \
  "$ENV_DIR/20-authentik.env" \
  "$ENV_DIR/30-gitea.env" \
  "$ENV_DIR/40-plane.env" \
  "$ENV_DIR/99-demo.env"

require_cmd python3
require_cmd docker
require_cmd curl
require_cmd jq
require_cmd mktemp

CATALOG_RUNTIME_PATH="${DEMO_DATA_CATALOG:-${LAB_PLATFORM_ROOT}/data-model/lab-domain.v0.3.yaml}"
CATALOG_REPO_PATH="$SCRIPT_DIR/../data-model/lab-domain.v0.3.yaml"
CATALOG_PATH=""
if [[ -f "$CATALOG_RUNTIME_PATH" ]]; then
  CATALOG_PATH="$CATALOG_RUNTIME_PATH"
elif [[ -z "${DEMO_DATA_CATALOG:-}" && -f "$CATALOG_REPO_PATH" ]]; then
  CATALOG_PATH="$CATALOG_REPO_PATH"
else
  die "demo data catalog not found at $CATALOG_RUNTIME_PATH or $CATALOG_REPO_PATH"
fi

CATALOG_TMP_DIR="$(mktemp -d)"
CATALOG_JSON="$CATALOG_TMP_DIR/lab-domain.v0.3.json"
gitea_netrc=""
gitea_tmp_dir=""

cleanup_tmp() {
  if [[ -n "$CATALOG_TMP_DIR" && -d "$CATALOG_TMP_DIR" ]]; then
    rm -rf "$CATALOG_TMP_DIR"
  fi
  if [[ -n "$gitea_tmp_dir" && -d "$gitea_tmp_dir" ]]; then
    rm -rf "$gitea_tmp_dir"
  fi
}
trap cleanup_tmp EXIT

python3 - "$CATALOG_PATH" "$CATALOG_JSON" <<'PY'
import json
import sys

try:
    import yaml
except ModuleNotFoundError:
    sys.stderr.write("ERROR: Python module 'yaml' (PyYAML) is required to read the demo data catalog\n")
    sys.exit(3)

source, target = sys.argv[1], sys.argv[2]
with open(source, "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}
with open(target, "w", encoding="utf-8") as handle:
    json.dump(data, handle, ensure_ascii=True)
PY

catalog_required() {
  local expression="$1"
  local value
  value="$(jq -er "$expression" "$CATALOG_JSON")" || die "demo data catalog missing required value: $expression"
  printf '%s' "$value"
}

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
PLANE_CONTAINER="${PLANE_CONTAINER:-plane-api}"

DEMO_USERNAME="${DEMO_USERNAME:-$(catalog_required 'first(.lab_users[] | select(.phase == "seed" and .system_of_record == "Authentik")).username')}"
DEMO_EMAIL="${DEMO_EMAIL:-$(catalog_required 'first(.lab_users[] | select(.phase == "seed" and .system_of_record == "Authentik")).email')}"
DEMO_DISPLAY_NAME="${DEMO_DISPLAY_NAME:-$(catalog_required 'first(.lab_users[] | select(.phase == "seed" and .system_of_record == "Authentik")).display_name')}"
DEMO_PASSWORD="${DEMO_PASSWORD:-}"
DEMO_AUTHENTIK_GROUP="${DEMO_AUTHENTIK_GROUP:-$(catalog_required 'first(.lab_users[] | select(.phase == "seed" and .system_of_record == "Authentik")).groups[0]')}"
DEMO_GITEA_OWNER="${DEMO_GITEA_OWNER:-${GITEA_BOOTSTRAP_ADMIN_USER:-gitea-bootstrap-admin}}"
DEMO_PLANE_WORKSPACE_SLUG="${DEMO_PLANE_WORKSPACE_SLUG:-$(catalog_required 'first(.plane.workspaces[] | select(.phase == "seed")).slug')}"
DEMO_PLANE_WORKSPACE_NAME="${DEMO_PLANE_WORKSPACE_NAME:-$(catalog_required 'first(.plane.workspaces[] | select(.phase == "seed")).name')}"
GITEA_BASE_URL="${GITEA_EXTERNAL_URL:-https://hub.lab.snu.ac.kr}"
GITEA_BASE_URL="${GITEA_BASE_URL%/}"
GITEA_NETRC_HOST="${GITEA_BASE_URL#http://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST#https://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST%%/*}"

[[ -n "$DEMO_PASSWORD" && "$DEMO_PASSWORD" != change-me-* ]] || die "DEMO_PASSWORD must be configured in $ENV_DIR/99-demo.env"
[[ -n "${GITEA_BOOTSTRAP_ADMIN_USER:-}" && -n "${GITEA_BOOTSTRAP_ADMIN_PASSWORD:-}" ]] || die "GITEA_BOOTSTRAP_ADMIN_USER/PASSWORD must be configured"
[[ "$DEMO_GITEA_OWNER" == "$GITEA_BOOTSTRAP_ADMIN_USER" ]] || die "DEMO_GITEA_OWNER must be the configured Gitea bootstrap admin for this script"
log "Using demo data catalog: $CATALOG_PATH"

write_secret_to_container() {
  local container="$1"
  local path="$2"
  local value="$3"
  printf '%s' "$value" | docker exec -i "$container" sh -c "umask 077; cat > '$path'"
}

seed_authentik_user() {
  local password_file="/tmp/lab-demo-password"

  write_secret_to_container "$AUTHENTIK_WORKER_CONTAINER" "$password_file" "$DEMO_PASSWORD"
  docker exec \
    -e "DEMO_USERNAME=$DEMO_USERNAME" \
    -e "DEMO_EMAIL=$DEMO_EMAIL" \
    -e "DEMO_DISPLAY_NAME=$DEMO_DISPLAY_NAME" \
    -e "DEMO_AUTHENTIK_GROUP=$DEMO_AUTHENTIK_GROUP" \
    -e "DEMO_PASSWORD_FILE=$password_file" \
    "$AUTHENTIK_WORKER_CONTAINER" ak shell -c '
import os
from authentik.core.models import Group, User

password_path = os.environ["DEMO_PASSWORD_FILE"]
with open(password_path, "r", encoding="utf-8") as handle:
    password = handle.read()
try:
    os.remove(password_path)
except FileNotFoundError:
    pass

username = os.environ["DEMO_USERNAME"]
email = os.environ["DEMO_EMAIL"]
display_name = os.environ["DEMO_DISPLAY_NAME"]
group_name = os.environ["DEMO_AUTHENTIK_GROUP"]

user, _ = User.objects.get_or_create(username=username)
user.email = email
user.name = display_name
user.is_active = True
user.set_password(password)
user.save()

group, _ = Group.objects.get_or_create(name=group_name)
group.users.add(user)
print(f"authentik demo user ready: {username} ({email}) in {group_name}")
'
}

init_gitea_auth() {
  gitea_tmp_dir="$(mktemp -d)"
  gitea_netrc="$gitea_tmp_dir/netrc"
  chmod 0700 "$gitea_tmp_dir"
  cat >"$gitea_netrc" <<NETRC
machine $GITEA_NETRC_HOST
login $GITEA_BOOTSTRAP_ADMIN_USER
password $GITEA_BOOTSTRAP_ADMIN_PASSWORD
NETRC
  chmod 0600 "$gitea_netrc"
}

gitea_request() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local output="$4"
  local status
  local curl_args=(-sS -k --netrc-file "$gitea_netrc" -H "Content-Type: application/json" -X "$method" -o "$output" -w "%{http_code}")
  if [[ -n "$data" ]]; then
    curl_args+=(-d "$data")
  fi
  curl_args+=("$GITEA_BASE_URL$path")
  status="$(curl "${curl_args[@]}")"
  printf '%s' "$status"
}

ensure_gitea_repo() {
  local repo="$1"
  local description="$2"
  local private="$3"
  local default_branch="$4"
  local output="$gitea_tmp_dir/repo.json"
  local payload status

  status="$(gitea_request GET "/api/v1/repos/$DEMO_GITEA_OWNER/$repo" "" "$output")"
  if [[ "$status" == "200" ]]; then
    log "Gitea repo already exists: $DEMO_GITEA_OWNER/$repo"
    return 0
  fi
  [[ "$status" == "404" ]] || die "Gitea repo lookup failed for $repo with HTTP $status"

  payload="$(jq -n \
    --arg name "$repo" \
    --arg description "$description" \
    --argjson private "$private" \
    --arg default_branch "$default_branch" \
    '{name: $name, description: $description, private: $private, auto_init: true, default_branch: $default_branch}')"
  status="$(gitea_request POST "/api/v1/user/repos" "$payload" "$output")"
  [[ "$status" == "201" || "$status" == "409" ]] || die "Gitea repo create failed for $repo with HTTP $status"
  log "Gitea repo ready: $DEMO_GITEA_OWNER/$repo"
}

put_gitea_file_encoded() {
  local repo="$1"
  local branch="$2"
  local path="$3"
  local message="$4"
  local encoded="$5"
  local get_output="$gitea_tmp_dir/content-get.json"
  local put_output="$gitea_tmp_dir/content-put.json"
  local existing payload sha status method endpoint

  status="$(gitea_request GET "/api/v1/repos/$DEMO_GITEA_OWNER/$repo/contents/$path?ref=$branch" "" "$get_output")"
  if [[ "$status" == "200" ]]; then
    sha="$(jq -r '.sha // empty' "$get_output")"
    existing="$(jq -r '.content // empty' "$get_output" | tr -d '\n')"
    if [[ "$existing" == "$encoded" ]]; then
      return 0
    fi
    method="PUT"
  elif [[ "$status" == "404" ]]; then
    sha=""
    method="POST"
  else
    die "Gitea file lookup failed for $repo/$path with HTTP $status"
  fi

  payload="$(jq -n \
    --arg content "$encoded" \
    --arg message "$message" \
    --arg branch "$branch" \
    --arg sha "$sha" \
    '{content: $content, message: $message, branch: $branch} + (if $sha == "" then {} else {sha: $sha} end)')"
  endpoint="/api/v1/repos/$DEMO_GITEA_OWNER/$repo/contents/$path"
  status="$(gitea_request "$method" "$endpoint" "$payload" "$put_output")"
  [[ "$status" == "200" || "$status" == "201" ]] || die "Gitea file upsert failed for $repo/$path with HTTP $status"
}

seed_gitea_repos() {
  local repo_count repo_json repo description visibility private default_branch file_json path message encoded

  init_gitea_auth

  repo_count="$(jq '[.code_repositories[] | select(.phase == "seed" and .system_of_record == "Gitea")] | length' "$CATALOG_JSON")"
  [[ "$repo_count" -gt 0 ]] || die "demo data catalog has no seed Gitea repositories"

  while IFS= read -r repo_json; do
    repo="$(jq -er '.name' <<<"$repo_json")" || die "Gitea repository catalog entry is missing name"
    description="$(jq -r '.description // ""' <<<"$repo_json")"
    visibility="$(jq -r '.visibility // "public"' <<<"$repo_json")"
    private="false"
    if [[ "$visibility" == "private" ]]; then
      private="true"
    fi
    default_branch="$(jq -r '.default_branch // "main"' <<<"$repo_json")"
    ensure_gitea_repo "$repo" "$description" "$private" "$default_branch"

    while IFS= read -r file_json; do
      path="$(jq -er '.path' <<<"$file_json")" || die "Gitea file catalog entry is missing path for $repo"
      message="$(jq -r '.message // ("Seed " + .path)' <<<"$file_json")"
      encoded="$(jq -er '.content | @base64' <<<"$file_json")" || die "Gitea file catalog entry is missing content for $repo/$path"
      put_gitea_file_encoded "$repo" "$default_branch" "$path" "$message" "$encoded"
    done < <(jq -c '.files[]' <<<"$repo_json")
  done < <(jq -c '.code_repositories[] | select(.phase == "seed" and .system_of_record == "Gitea")' "$CATALOG_JSON")
}

seed_plane_workspace() {
  local password_file="/tmp/lab-demo-password"
  local seed_file="/tmp/lab-demo-plane-seed.json"
  local workspace_json

  workspace_json="$(jq -c --arg slug "$DEMO_PLANE_WORKSPACE_SLUG" 'first(.plane.workspaces[] | select(.phase == "seed" and .slug == $slug))' "$CATALOG_JSON")"
  [[ "$workspace_json" != "null" ]] || die "demo data catalog has no seed Plane workspace with slug $DEMO_PLANE_WORKSPACE_SLUG"

  write_secret_to_container "$PLANE_CONTAINER" "$password_file" "$DEMO_PASSWORD"
  write_secret_to_container "$PLANE_CONTAINER" "$seed_file" "$workspace_json"
  docker exec \
    -e "DEMO_EMAIL=$DEMO_EMAIL" \
    -e "DEMO_USERNAME=$DEMO_USERNAME" \
    -e "DEMO_DISPLAY_NAME=$DEMO_DISPLAY_NAME" \
    -e "DEMO_PLANE_WORKSPACE_SLUG=$DEMO_PLANE_WORKSPACE_SLUG" \
    -e "DEMO_PLANE_WORKSPACE_NAME=$DEMO_PLANE_WORKSPACE_NAME" \
    -e "DEMO_PASSWORD_FILE=$password_file" \
    -e "DEMO_PLANE_SEED_FILE=$seed_file" \
    "$PLANE_CONTAINER" python manage.py shell -c '
import html
import json
import os
from plane.db.models import (
    Issue,
    IssueAssignee,
    Profile,
    Project,
    ProjectIdentifier,
    ProjectMember,
    State,
    User,
    Workspace,
    WorkspaceMember,
)

password_path = os.environ["DEMO_PASSWORD_FILE"]
with open(password_path, "r", encoding="utf-8") as handle:
    password = handle.read()
try:
    os.remove(password_path)
except FileNotFoundError:
    pass

seed_path = os.environ["DEMO_PLANE_SEED_FILE"]
with open(seed_path, "r", encoding="utf-8") as handle:
    seed = json.load(handle)
try:
    os.remove(seed_path)
except FileNotFoundError:
    pass

email = os.environ["DEMO_EMAIL"].lower()
username = os.environ["DEMO_USERNAME"]
display_name = os.environ["DEMO_DISPLAY_NAME"]
workspace_slug = os.environ["DEMO_PLANE_WORKSPACE_SLUG"]
workspace_name = os.environ["DEMO_PLANE_WORKSPACE_NAME"]
timezone = seed.get("timezone", "Asia/Seoul")
organization_size = str(seed.get("organization_size", "1-10"))
state_specs = seed.get("states", [])
projects = seed.get("projects", [])
if not state_specs:
    raise ValueError("Plane workspace seed requires at least one state")
default_state_name = next((state["name"] for state in state_specs if state.get("default")), state_specs[0]["name"])

user, created = User.objects.get_or_create(
    email=email,
    defaults={
        "username": username,
        "display_name": display_name,
        "is_active": True,
        "is_email_verified": True,
    },
)
user.username = username
user.display_name = display_name
user.is_active = True
user.is_email_verified = True
user.set_password(password)
user.save()

workspace, _ = Workspace.objects.update_or_create(
    slug=workspace_slug,
    defaults={
        "name": workspace_name,
        "owner": user,
        "organization_size": organization_size,
        "timezone": timezone,
    },
)
WorkspaceMember.objects.update_or_create(
    workspace=workspace,
    member=user,
    defaults={"role": 20, "company_role": "Research member", "is_active": True},
)
profile, _ = Profile.objects.get_or_create(user=user)
profile.is_onboarded = True
profile.is_tour_completed = True
profile.last_workspace_id = workspace.id
profile.onboarding_step = {
    "profile_complete": True,
    "workspace_create": True,
    "workspace_invite": True,
    "workspace_join": True,
}
profile.use_case = "Demo"
profile.role = "Research member"
profile.company_name = workspace_name
profile.save()

for project_spec in projects:
    project_name = project_spec["name"]
    identifier = project_spec["identifier"]
    description = project_spec.get("description", "")
    project, _ = Project.objects.update_or_create(
        workspace=workspace,
        name=project_name,
        defaults={
            "identifier": identifier,
            "description": description,
            "network": 2,
            "project_lead": user,
            "default_assignee": user,
            "timezone": timezone,
        },
    )
    ProjectIdentifier.objects.update_or_create(
        workspace=workspace,
        project=project,
        defaults={"name": identifier},
    )
    ProjectMember.objects.update_or_create(
        workspace=workspace,
        project=project,
        member=user,
        defaults={"role": 20, "is_active": True},
    )

    states = {}
    for sequence, state_spec in enumerate(state_specs, start=1):
        state_name = state_spec["name"]
        state, _ = State.objects.update_or_create(
            workspace=workspace,
            project=project,
            name=state_name,
            defaults={
                "group": state_spec["group"],
                "color": state_spec["color"],
                "default": bool(state_spec.get("default", False)),
                "sequence": sequence * 15000,
            },
        )
        states[state_name] = state
    project.default_state = states[default_state_name]
    project.save()

    for issue_spec in project_spec.get("issues", []):
        issue_name = issue_spec["name"]
        state_name = issue_spec.get("state", default_state_name)
        issue = Issue.objects.filter(workspace=workspace, project=project, name=issue_name).first()
        if issue is None:
            issue = Issue(workspace=workspace, project=project, name=issue_name)
        issue.priority = issue_spec.get("priority", "none")
        issue.state = states[state_name]
        issue.description = {}
        description_text = html.escape(issue_spec.get("description", ""))
        issue.description_html = f"<p>{description_text}</p>"
        issue.save()
        IssueAssignee.objects.update_or_create(
            workspace=workspace,
            project=project,
            issue=issue,
            assignee=user,
            defaults={},
        )

print(
    "plane demo workspace ready: "
    f"{workspace_slug} ({Project.objects.filter(workspace=workspace).count()} projects, "
    f"{Issue.objects.filter(workspace=workspace).count()} issues)"
)
'
}

seed_authentik_user
seed_gitea_repos
seed_plane_workspace

echo "demo data seed completed"
echo "Auth user: $DEMO_USERNAME / $DEMO_EMAIL"
echo "Gitea public repos:"
while IFS= read -r repo; do
  echo "  $GITEA_BASE_URL/$DEMO_GITEA_OWNER/$repo"
done < <(jq -r '.code_repositories[] | select(.phase == "seed" and .system_of_record == "Gitea") | .name' "$CATALOG_JSON")
echo "Plane workspace slug: $DEMO_PLANE_WORKSPACE_SLUG"
