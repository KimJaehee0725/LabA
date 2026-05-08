# Incident Response

1. Decide whether the affected public route should be disabled in Nginx.
2. Preserve logs and current container state.
3. Check Authentik events and app audit logs.
4. Assess whether secrets, tokens, TLS keys, or backups were exposed.
5. Rotate only scoped credentials after evidence is preserved.
6. Restore from backups only after identifying the affected data boundary.
