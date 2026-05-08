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

## Seed Demo Data

Copy the updated scripts to `/srv/lab-platform/scripts`, then run:

```bash
sudo /srv/lab-platform/scripts/52-seed-demo-data.sh
```

The script creates:

- an Authentik demo user in `lab-member`
- public Gitea demo repositories under the bootstrap admin account
- a Plane local demo user, workspace, projects, states, and issues

The Gitea repositories are public so they can be shown without depending on Gitea login. Plane uses a local demo login until the v0.3.0 Plane/Auth generic OIDC blocker is closed.

## Cleanup

To remove the seeded demo content:

```bash
sudo /srv/lab-platform/scripts/53-clean-demo-data.sh
```

Cleanup removes the demo Authentik user, the public demo repositories, and the Plane demo workspace/user. It does not remove the Gitea bootstrap admin.
