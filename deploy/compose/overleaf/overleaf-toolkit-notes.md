# Overleaf Toolkit Notes

Overleaf recommends Toolkit for Community Edition and Server Pro operations. The v0.2 platform keeps a direct Compose module for consistency with shared Nginx, backups, and env layout, while preserving these Toolkit review requirements:

- Re-check Toolkit release notes before changing `OVERLEAF_IMAGE`.
- Keep MongoDB replica set initialization in the runbook.
- Treat admin activation URLs as secrets.
- Keep Authentik SSO out of v0.3 scope; CE uses manual accounts and invitations.
- Validate Korean LaTeX packages in the custom image before smoke signoff.
