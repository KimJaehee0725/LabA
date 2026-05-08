# Update Policy

1. Read release notes for one service at a time.
2. Run a backup or backup dry-run.
3. Update image tag in the relevant env file.
4. Run `docker compose config`.
5. Pull or build.
6. Start the module.
7. Check logs and module smoke.
8. Record the change in `history/`.

Avoid unpinned `latest` tags and avoid simultaneous database migrations across multiple services.
