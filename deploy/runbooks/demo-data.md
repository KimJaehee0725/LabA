# Demo Data Runbook

Use this only on the staging server when a small professor-facing demo needs non-sensitive sample content.

## Create the Runtime Env

Create `/srv/lab-platform/env/99-demo.env` from `deploy/env/99-demo.env.example` and generate `DEMO_PASSWORD` on the server. Do not commit or paste the generated password.

Required fields:

- `DEMO_USERNAME`
- `DEMO_EMAIL`
- `DEMO_DISPLAY_NAME`
- `DEMO_PASSWORD`
- `DEMO_AUTHENTIK_GROUP`
- `DEMO_GITEA_OWNER`
- `DEMO_PLANE_WORKSPACE_SLUG`
- `DEMO_PLANE_WORKSPACE_NAME`

Gitea API auth can use either `GITEA_BOOTSTRAP_ADMIN_PASSWORD` from the normal Gitea env or a temporary `GITEA_BOOTSTRAP_ADMIN_TOKEN` exported only for the seed/cleanup command. Do not commit either value.

## Prepare the Catalog

Copy the non-secret catalog to the runtime data-model directory:

```bash
sudo install -d -m 0755 /srv/lab-platform/data-model
sudo install -m 0644 deploy/data-model/lab-domain.v0.3.yaml /srv/lab-platform/data-model/lab-domain.v0.3.yaml
```

Validate it on the host before seeding:

```bash
python3 -c "import yaml; yaml.safe_load(open('/srv/lab-platform/data-model/lab-domain.v0.3.yaml'))"
```

`52-seed-demo-data.sh` uses `/srv/lab-platform/data-model/lab-domain.v0.3.yaml` by default. If that file is absent and the script is run from the repository, it falls back to `deploy/data-model/lab-domain.v0.3.yaml`. To seed the v0.4 workspace catalog, install `deploy/data-model/lab-domain.v0.4.yaml` and run with `LAB_DOMAIN_CATALOG_VERSION=v0.4`. To test a different catalog, set `DEMO_DATA_CATALOG=/path/to/catalog.yaml`.

## Seed Demo Data

Copy the updated scripts and catalog to `/srv/lab-platform`, then run:

```bash
sudo /srv/lab-platform/scripts/52-seed-demo-data.sh
```

For the v0.4 workspace seed:

```bash
sudo LAB_DOMAIN_CATALOG_VERSION=v0.4 /srv/lab-platform/scripts/52-seed-demo-data.sh
sudo LAB_DOMAIN_CATALOG_VERSION=v0.4 /srv/lab-platform/scripts/73-seed-nextcloud-document-hub.sh
sudo /srv/lab-platform/scripts/75-seed-grist-research-hub.sh
```

The script creates:

- an Authentik demo user in `lab-member`
- public Gitea demo repositories under the bootstrap admin account
- a Plane demo user, workspace, projects, states, labels, due dates, reference links, and issues

The seeded Gitea repositories, repository files, Plane workspace, Plane projects, and Plane issues are read from the YAML catalog. The demo password and service credentials are read only from `/srv/lab-platform/env/*.env`.

The Gitea repositories are public so they can be shown without depending on Gitea login. Plane should be shown through Authentik OIDC; the local demo login remains available for break-glass checks.

## Cleanup

To remove the seeded demo content:

```bash
sudo /srv/lab-platform/scripts/53-clean-demo-data.sh
```

Cleanup removes the demo Authentik user, the public demo repositories, and the Plane demo workspace/user. It does not remove the Gitea bootstrap admin.
