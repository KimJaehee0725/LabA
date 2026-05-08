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

require_cmd docker
require_cmd curl
require_cmd jq
require_cmd base64
require_cmd mktemp

AUTHENTIK_WORKER_CONTAINER="${AUTHENTIK_WORKER_CONTAINER:-authentik-worker}"
PLANE_CONTAINER="${PLANE_CONTAINER:-plane-api}"

DEMO_USERNAME="${DEMO_USERNAME:-demo.member}"
DEMO_EMAIL="${DEMO_EMAIL:-demo.member@example.invalid}"
DEMO_DISPLAY_NAME="${DEMO_DISPLAY_NAME:-Demo Member}"
DEMO_PASSWORD="${DEMO_PASSWORD:-}"
DEMO_AUTHENTIK_GROUP="${DEMO_AUTHENTIK_GROUP:-lab-member}"
DEMO_GITEA_OWNER="${DEMO_GITEA_OWNER:-${GITEA_BOOTSTRAP_ADMIN_USER:-gitea-bootstrap-admin}}"
DEMO_PLANE_WORKSPACE_SLUG="${DEMO_PLANE_WORKSPACE_SLUG:-lab-demo}"
DEMO_PLANE_WORKSPACE_NAME="${DEMO_PLANE_WORKSPACE_NAME:-Lab Demo Workspace}"
GITEA_BASE_URL="${GITEA_EXTERNAL_URL:-https://hub.lab.snu.ac.kr}"
GITEA_BASE_URL="${GITEA_BASE_URL%/}"
GITEA_NETRC_HOST="${GITEA_BASE_URL#http://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST#https://}"
GITEA_NETRC_HOST="${GITEA_NETRC_HOST%%/*}"

[[ -n "$DEMO_PASSWORD" && "$DEMO_PASSWORD" != change-me-* ]] || die "DEMO_PASSWORD must be configured in $ENV_DIR/99-demo.env"
[[ -n "${GITEA_BOOTSTRAP_ADMIN_USER:-}" && -n "${GITEA_BOOTSTRAP_ADMIN_PASSWORD:-}" ]] || die "GITEA_BOOTSTRAP_ADMIN_USER/PASSWORD must be configured"
[[ "$DEMO_GITEA_OWNER" == "$GITEA_BOOTSTRAP_ADMIN_USER" ]] || die "DEMO_GITEA_OWNER must be the configured Gitea bootstrap admin for this script"

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

group = Group.objects.get(name=group_name)
group.users.add(user)
print(f"authentik demo user ready: {username} ({email}) in {group_name}")
'
}

gitea_netrc=""
gitea_tmp_dir=""

cleanup_gitea_tmp() {
  if [[ -n "$gitea_tmp_dir" && -d "$gitea_tmp_dir" ]]; then
    rm -rf "$gitea_tmp_dir"
  fi
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
  trap cleanup_gitea_tmp EXIT
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
    '{name: $name, description: $description, private: false, auto_init: true, default_branch: "main"}')"
  status="$(gitea_request POST "/api/v1/user/repos" "$payload" "$output")"
  [[ "$status" == "201" || "$status" == "409" ]] || die "Gitea repo create failed for $repo with HTTP $status"
  log "Gitea repo ready: $DEMO_GITEA_OWNER/$repo"
}

put_gitea_file() {
  local repo="$1"
  local path="$2"
  local message="$3"
  local content="$4"
  local get_output="$gitea_tmp_dir/content-get.json"
  local put_output="$gitea_tmp_dir/content-put.json"
  local encoded existing payload sha status method endpoint

  encoded="$(printf '%s' "$content" | base64 | tr -d '\n')"
  status="$(gitea_request GET "/api/v1/repos/$DEMO_GITEA_OWNER/$repo/contents/$path?ref=main" "" "$get_output")"
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
    --arg branch "main" \
    --arg sha "$sha" \
    '{content: $content, message: $message, branch: $branch} + (if $sha == "" then {} else {sha: $sha} end)')"
  endpoint="/api/v1/repos/$DEMO_GITEA_OWNER/$repo/contents/$path"
  status="$(gitea_request "$method" "$endpoint" "$payload" "$put_output")"
  [[ "$status" == "200" || "$status" == "201" ]] || die "Gitea file upsert failed for $repo/$path with HTTP $status"
}

seed_gitea_repos() {
  init_gitea_auth

  ensure_gitea_repo "lab-platform-demo" "Staging platform demo notes for the current deployment wave."
  put_gitea_file "lab-platform-demo" "README.md" "Seed demo README" "# Lab Platform Demo

This repository is demo data for the staging Lab Platform.

It gives visitors a quick, non-sensitive walkthrough of the current platform wave:

- Authentik identity foundation
- Gitea source hosting
- Plane project tracking
- Edge routing through Nginx

Do not store real credentials or research data here.
"
  put_gitea_file "lab-platform-demo" "docs/demo-tour.md" "Seed demo tour" "# Demo Tour

1. Open the platform entry points through the staging host aliases.
2. Show that Authentik has the lab groups and a demo member account.
3. Open Gitea Explore and show public demo repositories.
4. Log in to Plane with the local demo account and open the seeded workspace.

Known v0.3.0 follow-up: finish generic OIDC login for Plane.
"
  put_gitea_file "lab-platform-demo" "deploy-notes/current-wave.md" "Seed current wave note" "# Current Wave

Runtime validation is focused on the staging stack that is already running:

- core services
- edge Nginx
- Authentik
- Gitea
- Plane local runtime/data paths

The next integration task is to close the Plane/Auth SSO gap.
"

  ensure_gitea_repo "vision-baseline-demo" "Small public sample repository for a lab model baseline."
  put_gitea_file "vision-baseline-demo" "README.md" "Seed vision demo README" "# Vision Baseline Demo

This is placeholder demo content for a lab code repository.

It is intentionally small and contains no private dataset, model weight, or credential.
"
  put_gitea_file "vision-baseline-demo" "train.py" "Seed sample training script" "def main():
    metrics = {\"accuracy\": 0.91, \"loss\": 0.23}
    for key, value in metrics.items():
        print(f\"{key}: {value}\")


if __name__ == \"__main__\":
    main()
"
  put_gitea_file "vision-baseline-demo" "metrics/sample-run.json" "Seed sample metrics" "{
  \"run_name\": \"demo-baseline-001\",
  \"accuracy\": 0.91,
  \"loss\": 0.23,
  \"notes\": \"Synthetic demo metrics only\"
}
"

  ensure_gitea_repo "paper-template-demo" "Minimal paper template for the collaboration app wave demo."
  put_gitea_file "paper-template-demo" "README.md" "Seed paper template README" "# Paper Template Demo

This repository is demo content for the future Overleaf/collaboration wave.
"
  put_gitea_file "paper-template-demo" "main.tex" "Seed paper template" "\\documentclass{article}
\\title{Lab Platform Demo Paper}
\\author{Demo Member}
\\begin{document}
\\maketitle
\\section{Overview}
This is a synthetic paper template for the staging demo.
\\end{document}
"
}

seed_plane_workspace() {
  local password_file="/tmp/lab-demo-password"

  write_secret_to_container "$PLANE_CONTAINER" "$password_file" "$DEMO_PASSWORD"
  docker exec \
    -e "DEMO_EMAIL=$DEMO_EMAIL" \
    -e "DEMO_USERNAME=$DEMO_USERNAME" \
    -e "DEMO_DISPLAY_NAME=$DEMO_DISPLAY_NAME" \
    -e "DEMO_PLANE_WORKSPACE_SLUG=$DEMO_PLANE_WORKSPACE_SLUG" \
    -e "DEMO_PLANE_WORKSPACE_NAME=$DEMO_PLANE_WORKSPACE_NAME" \
    -e "DEMO_PASSWORD_FILE=$password_file" \
    "$PLANE_CONTAINER" python manage.py shell -c '
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

email = os.environ["DEMO_EMAIL"].lower()
username = os.environ["DEMO_USERNAME"]
display_name = os.environ["DEMO_DISPLAY_NAME"]
workspace_slug = os.environ["DEMO_PLANE_WORKSPACE_SLUG"]
workspace_name = os.environ["DEMO_PLANE_WORKSPACE_NAME"]

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
        "organization_size": "1-10",
        "timezone": "Asia/Seoul",
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

projects = [
    (
        "Platform Rollout",
        "ROLL",
        "Demo project for staging rollout tasks.",
        [
            ("Confirm professor demo path", "high", "Ready", "Validate the browser path and demo credentials before the walkthrough."),
            ("Close Plane generic OIDC gap", "urgent", "In Progress", "Track the v0.3.0 blocker for Authentik to Plane login."),
            ("Prepare app wave smoke checks", "medium", "Backlog", "Draft checks for Gitea and Plane before adding the next apps."),
        ],
    ),
    (
        "Research Workbench",
        "RND",
        "Demo project for research workflow tasks.",
        [
            ("Register baseline experiment", "medium", "Ready", "Create a sample experiment record and link code artifacts."),
            ("Upload sanitized sample dataset", "low", "Backlog", "Use synthetic data only for staging demos."),
            ("Write reproducibility note", "medium", "Done", "Document how the demo result can be reproduced."),
        ],
    ),
]
state_specs = [
    ("Backlog", "backlog", "#6B7280", True),
    ("Ready", "unstarted", "#2563EB", False),
    ("In Progress", "started", "#F59E0B", False),
    ("Done", "completed", "#16A34A", False),
]

for project_name, identifier, description, issue_specs in projects:
    project, _ = Project.objects.update_or_create(
        workspace=workspace,
        name=project_name,
        defaults={
            "identifier": identifier,
            "description": description,
            "network": 2,
            "project_lead": user,
            "default_assignee": user,
            "timezone": "Asia/Seoul",
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
    for sequence, (state_name, group, color, is_default) in enumerate(state_specs, start=1):
        state, _ = State.objects.update_or_create(
            workspace=workspace,
            project=project,
            name=state_name,
            defaults={
                "group": group,
                "color": color,
                "default": is_default,
                "sequence": sequence * 15000,
            },
        )
        states[state_name] = state
    project.default_state = states["Backlog"]
    project.save()

    for issue_name, priority, state_name, description_text in issue_specs:
        issue = Issue.objects.filter(workspace=workspace, project=project, name=issue_name).first()
        if issue is None:
            issue = Issue(workspace=workspace, project=project, name=issue_name)
        issue.priority = priority
        issue.state = states[state_name]
        issue.description = {}
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
echo "  $GITEA_BASE_URL/$DEMO_GITEA_OWNER/lab-platform-demo"
echo "  $GITEA_BASE_URL/$DEMO_GITEA_OWNER/vision-baseline-demo"
echo "  $GITEA_BASE_URL/$DEMO_GITEA_OWNER/paper-template-demo"
echo "Plane workspace slug: $DEMO_PLANE_WORKSPACE_SLUG"
